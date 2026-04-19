# webhook/server.cr - Webhook server for Telecr bots
require "http/server"
require "yaml"
require "openssl"
require "json"
require "uri"
require "log"

module Telecr
  module Webhook
    class Server
      Log = ::Log.for("telecr.webhook")

      getter bot : Telecr::Core::Bot
      getter port : Int32
      getter host : String
      getter secret_token : String
      getter? running : Bool = false
      getter ssl_mode : Symbol
      @server : HTTP::Server?
      @ssl_context : OpenSSL::SSL::Context::Server?

      def initialize(
        @bot : Core::Bot,
        port : Int32? = nil,
        @host : String = "0.0.0.0",
        secret_token : String? = nil,
        ssl : (Bool | Hash(Symbol, String))? = nil
      )
        @port = port || ENV["PORT"]?.try(&.to_i) || 3000
        @secret_token = secret_token || Random::Secure.hex(16)
        
        # Determine SSL mode using  original priority logic
        @ssl_mode, @ssl_context = determine_ssl_mode(ssl)
        
        log_configuration
      end

      private def determine_ssl_mode(ssl_options) : {Symbol, OpenSSL::SSL::Context::Server?}
        return {:none, nil} if ssl_options == false
        
        # Preservation: Loading from .telecr-ssl config file
        if File.exists?(".telecr-ssl")
          begin
            config = YAML.parse(File.read(".telecr-ssl"))
            cert_path = config["cert_path"]?.try(&.to_s)
            key_path = config["key_path"]?.try(&.to_s)
            
            if cert_path && key_path && File.exists?(cert_path) && File.exists?(key_path)
              context = load_certificate_files(cert_path, key_path)
              return {:cli, context} if context
            end
          rescue e
            Log.warn { "Failed to load .telecr-ssl config: #{e.message}" }
          end
        end
        
        # Manual SSL via options hash
        if ssl_options.is_a?(Hash)
          cert_path = ssl_options[:cert_path]?
          key_path = ssl_options[:key_path]?
          
          if cert_path && key_path && File.exists?(cert_path) && File.exists?(key_path)
            context = load_certificate_files(cert_path, key_path)
            return {:manual, context} if context
          end
        end

        # Cloud SSL (Reverse Proxy)
        if ENV["TELECR_WEBHOOK_URL"]?.try { |u| u.starts_with?("https") }
          return {:cloud, nil}
        end

        {:none, nil}
      end

      # Preservation:  original certificate loader
      private def load_certificate_files(cert_path : String, key_path : String) : OpenSSL::SSL::Context::Server?
        context = OpenSSL::SSL::Context::Server.new
        context.certificate_chain = cert_path
        context.private_key = key_path
        context
      rescue e
        Log.error { "Failed to load SSL certificates: #{e.message}" }
        nil
      end

      def run(**webhook_options)
        return if @running
        
        # Telegram strictly requires HTTPS for Webhooks
        if @ssl_mode == :none
          Log.error { "Telegram requires HTTPS. Use .telecr-ssl or a Cloud Proxy." }
          return
        end

        # Using the simplified 2026 HTTP::Server initialization
        @server = HTTP::Server.new(@host, @port, [@ssl_context].compact) do |context|
          handle_request(context)
        end

        @running = true
        spawn { @server.not_nil!.listen }
        
        # Register URL with Telegram
        set_webhook(**webhook_options)
      end

      private def handle_request(context)
        case context.request.path
        when "/#{@secret_token}"
          # Security: Validate Telegram Secret Token header if present
          if token = context.request.headers["X-Telegram-Bot-Api-Secret-Token"]?
            return access_denied(context) if token != @secret_token
          end
          process_update(context)
        when "/health", "/healthz"
          context.response.status = :ok
          context.response.print "OK"
        else
          context.response.status = :not_found
        end
      end

      private def process_update(context)
        if body = context.request.body.try(&.gets_to_end)
          begin
            @bot.process(JSON.parse(body))
            context.response.status = :ok
          rescue e : Exception
            Log.error { "Update processing failed: #{e.message}" }
            context.response.status = :internal_server_error
          end
        else
          context.response.status = :bad_request
        end
      end

      private def access_denied(context)
        context.response.status = :forbidden
        context.response.print "Unauthorized"
      end

      def set_webhook(**options)
        url = generate_url
        Log.info { "Setting Webhook: #{url}" }
        @bot.set_webhook(url: url, secret_token: @secret_token, **options)
      end

      private def generate_url : String
        base = ENV["TELECR_WEBHOOK_URL"]? || "https://#{@host}:#{@port}"
        "#{base.chomp("/")}/#{@secret_token}"
      end

      def stop
        @server.try(&.close)
        @running = false
      end

      private def log_configuration
        Log.info { "Webhook active. Host: #{@host}:#{@port}, Mode: #{@ssl_mode}" }
      end
    end
  end
end