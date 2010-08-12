module Sonar
  module Connector
    class ImapPullConnector < Sonar::Connector::Base

      # http://www.faqs.org/rfcs/rfc3501.html
      # min uid value is 1, so min last_uid is 0
      MIN_LAST_UID = 0

      # max uid value is 2**32-1
      MAX_UID = 2**32-1

      DEFAULT_SSL_PORT = 993
      DEFAULT_PLAIN_PORTDEFAULT_PLAIN_PORT = 143

      DEFAULT_BATCH_SIZE = 100
      
      attr_reader :host
      attr_reader :port
      attr_reader :usessl
      attr_reader :user
      attr_reader :password
      attr_reader :folders
      attr_reader :batch_size
      
      def parse(settings)
        ["host", "user", "password", "folders"].each do |param|
          raise Sonar::Connector::InvalidConfig.new("#{self.to_s}: param '#{param}' is blank") if settings[param].blank?
        end

        @host = settings["host"]
        @usessl = settings["usessl"] || true
        @port = settings["port"] || (@usessl ? DEFAULT_SSL_PORT : DEFAULT_PLAIN_PORT)
        @user = settings["user"]
        @password = settings["password"]
        @folders = settings["folders"]
        @batch_size = settings["batch_size"] || DEFAULT_BATCH_SIZE
      end

      def open_connection
        imap = Net::IMAP.new(host, port, usessl)
        imap.login(user, password)
        log.info "logged in"
        @imap = imap
      end

      def retrieve_imap
        @imap = nil if @imap && @imap.disconnected?
        @imap || open_connection
      end

      def action
        fs = [*folders]
        log.info "opening connection to : imap://#{user}@#{host}:#{port}/ for folders #{fs.inspect}"

        imap = retrieve_imap
        state[:folder_last_uids] ||= {}

        fs.each do |f|
          imap.select(f)
          next_uid = (state[:folder_last_uids][f] || MIN_LAST_UID) + 1

          log.info "retrieving from folder: #{f}, uid>=#{next_uid}"

          # min uid value is 1
          uids = imap.uid_search(["UID", "#{next_uid}:#{MAX_UID}"])[0...batch_size]
          uids.each do |uid|
            log.debug "[#{uid}]"
            fetch_and_save(imap, uid)
            state[:folder_last_uids][f] = uid
            save_state
          end
          log.info "finished folder: #{f}, last_uid=#{state[:folder_last_uids][f]}"
        end

        log.info "finished"
      end

      def fetch_and_save(imap, msg_uid)
        msg = imap.uid_fetch(msg_uid, "RFC822.HEADER")[0]
        headers = msg.attr["RFC822.HEADER"]
        content = "#{headers}\n\n\n\n\n\n"
        json = mail_to_json(content, Time.now)
        
        filestore.write(:complete, "#{msg_uid}.json", json)
      end

      def mail_to_json(content, timestamp)
        {
          "rfc822_base64"=>Base64.encode64(content),
          "name"=>self.name,
          "retrieved_at"=>timestamp.to_s,
          "source_info"=>"connector_class: #{self.class}, connector_name: #{self.name}, host: #{self.host}, port: #{self.port}, user: #{self.user}"
        }.to_json
      end
    end
  end
end
