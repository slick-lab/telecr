# plugins/upload.cr - File upload plugin using shrine

module Telecr
  module Plugins
    class Upload < Core::Middleware
      def initialize(@shrine)
        @logger = Log.for("upload")
      end

      def call(ctx : Core::Context, next_mw : Core::Context ->)
        if has_file?(ctx)
          process_file(ctx)
        end
        next_mw.call(ctx)
      end

      private def has_file?(ctx) : Bool
        if msg = ctx.message
          return true if msg.photo
          return true if msg.document
          return true if msg.video
        end
        false
      end

      private def process_file(ctx)
        if msg = ctx.message
          if photo = msg.photo
            file_id = photo[0].file_id
            upload_file(ctx, file_id, "photo.jpg")
          end
          if doc = msg.document
            file_id = doc.file_id
            upload_file(ctx, file_id, doc.file_name || "document.bin")
          end
        end
      end

      private def upload_file(ctx, file_id, filename)
        temp = File.tempfile
        ctx.bot.client.download(file_id, temp.path)

        File.open(temp.path) do |io|
          result = @shrine.upload(io, "telegram/#{file_id}/#{filename}")
          ctx.state[:uploaded_file] = result
        end

        temp.delete
      end
    end
  end
end
