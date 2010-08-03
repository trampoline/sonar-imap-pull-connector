module Sonar
  module Connector
    class ImapPullConnector < Sonar::Connector::Base

      # http://www.faqs.org/rfcs/rfc3501.html
      # min uid value is 1, so min last_uid is 0
      MIN_LAST_UID = 0

      # max uid value is 2**32-1
      MAX_UID = 2**32-1

      attr_reader :host
      attr_reader :port
      attr_reader :usessl
      attr_reader :user
      attr_reader :password
      attr_reader :folders
      
      def parse(settings)
        ["host", "port", "user", "password", "folders"].each do |param|
          raise Sonar::Connector::InvalidConfig.new("#{self.to_s}: param '#{param}' is blank") if settings[param].blank?
        end

        settings.each do |k,v|
          self.instance_variable_set("@#{k}", v)
        end
      end

      def action
        fs = [*folders]
        log.info "opening connection to : imap://#{user}@#{host}:#{port}/ for folders #{f.inspect}"

        imap = Net::IMAP.new(host, port, usessl)
        imap.login(user, pass)
        log.info "logged in"

        state[:folder_last_uids] ||= {}

        fs.each do |f|
          imap.select(f)
          next_uid = (state[:folder_last_uids][f] || MIN_LAST_UID) + 1

          log.info "retrieving from folder: #{f}, uid>=#{next_uid}"

          # min uid value is 1
          uids = imap.search(["UID", "#{next_uid}:#{MAX_UID}"])
          uids.each do |uid|
            fetch_and_save(imap, uid)
            state[:folder_last_uids][f] = uid
          end
          log.info "finished folder: #{f}, last_uid=#{state[:folder_last_uids][f]}"
        end

        log.info "finished"
      end

      def fetch_and_save(imap, msg_uid)
        msg = imap.uid_fetch(msg_uid, "RFC822.HEADER")[0]
        headers = msg.attr["RFC822.HEADER"]
        working.add("#{headers}\n\n\n\n\n\n", "#{msg_uid}")
      end
    end
  end
end
