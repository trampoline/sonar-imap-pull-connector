require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

module Sonar
  module Connector
    describe "SonarImapPullConnector" do
      
      describe "ImapConnectionTimeout" do
        class Foo
          include ImapConnectionTimeout
          attr_accessor :imap
          attr_accessor :log
        end

        it "should timeout and close a too-long running action" do
          f = Foo.new
          stub(f.log=Object.new).info
          mock(f.imap=Object.new).close
          
          lambda {
            f.with_connection_timeout(1) { sleep 2 }
          }.should raise_error(Timeout::Error)
          
          f.imap.should == nil
        end
        
      end
    end
  end
end
