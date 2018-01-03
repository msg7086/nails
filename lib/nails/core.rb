require 'base64'
require 'digest'
require 'streamio-ffmpeg'
require 'rmagick'
require 'fileutils'

module Nails
  TMP_DIR = "/tmp/nails-#{Process.uid}/"
  IMG_HEADER = 100
  IMG_PADDINGX = 9
  IMG_PADDINGY = 6
  IMG_OFFSET = 2
  IMG_BORDER = 1
  IMG_SHADOWX = 5
  IMG_SHADOWY = 3
  FONT = ENV['font'] || 'WenQuanYi-Micro-Hei'
  class Core
    include Magick

    def process(args)
      args.each do |file|
        video = ::FFMPEG::Movie.new(file)
        generate(video)
      end
    end

    def generate(video)
      images = screenshot(video, 12)
      paint(video, images)
    end

    def screenshot(video, count = 12)
      interval = video.duration / count
      seek_start = interval / 2
      cache_name = Base64.urlsafe_encode64(Digest::MD5.digest(video.path))
      FileUtils.mkdir(TMP_DIR) unless File.exist?(TMP_DIR)
      count.times.map do |x|
        seek = (seek_start + interval * x).round
        filename = "#{TMP_DIR}#{cache_name}-#{x}.png"
        video.screenshot(filename, {}, input_options: {:ss => seek.to_s}) unless File.exist? filename
        {idx: x, seek: seek, name: filename}
      end
    end

    def paint(video, images)
      base_width = video.width / 4
      base_height = video.height / 4
      out = Image.new(base_width * 4, base_height * 6 + IMG_HEADER) do
        self.background_color = 'white'
      end
      border = Draw.new
      border.fill = 'none'
      border.stroke = 'black'
      border.stroke_linejoin 'round'
      border.stroke_width = IMG_BORDER * 2
      shadow = Draw.new
      shadow.fill = 'grey'
      shadow.stroke = 'grey'
      shadow.stroke_linejoin 'round'
      shadow.stroke_width = IMG_BORDER * 2

      images.each do |image|
        box = get_box(image[:idx])
        a_x = box[0] * base_width
        a_y = box[1] * base_height + IMG_HEADER
        b_x = (box[0] + box[2]) * base_width - 1
        b_y = (box[1] + box[3]) * base_height + IMG_HEADER - 1
        border.rectangle(
          a_x + IMG_PADDINGX - IMG_OFFSET - IMG_BORDER,
          a_y + IMG_PADDINGY - IMG_OFFSET - IMG_BORDER,
          b_x - IMG_PADDINGX - IMG_OFFSET + IMG_BORDER,
          b_y - IMG_PADDINGY - IMG_OFFSET + IMG_BORDER)
        shadow.rectangle(
          a_x + IMG_PADDINGX - IMG_OFFSET - IMG_BORDER + IMG_SHADOWX,
          a_y + IMG_PADDINGY - IMG_OFFSET - IMG_BORDER + IMG_SHADOWY,
          b_x - IMG_PADDINGX - IMG_OFFSET + IMG_BORDER + IMG_SHADOWX,
          b_y - IMG_PADDINGY - IMG_OFFSET + IMG_BORDER + IMG_SHADOWY)
      end
      shadow.draw(out)
      border.draw(out)
      #return out.write('test.png')

      timestamp = Draw.new
      timestamp.font = 'Helvetica-Bold'
      timestamp.gravity = Magick::NorthWestGravity
      timestamp.pointsize = 24
      timestamp.fill = 'black'
      timestamp.font_weight = BoldWeight
      images.each do |image|
        box = get_box(image[:idx])
        video_pic = Image.read(image[:name]).first
        next unless video_pic
        video_pic.resize!(box[2] * base_width - IMG_PADDINGX * 2, box[3] * base_height - IMG_PADDINGY * 2)
        out.composite!(video_pic, box[0] * base_width + IMG_PADDINGX - IMG_OFFSET, box[1] * base_height + IMG_PADDINGY - IMG_OFFSET + IMG_HEADER, CopyCompositeOp)
        draw_with_shadow(timestamp, out, base_width, 26,
          box[0] * base_width + IMG_PADDINGX + 10,
          box[1] * base_height + IMG_PADDINGY + IMG_HEADER + 10,
          timestamp_format(image[:seek]))
      end

      vmeta = video.metadata[:streams].find{ |s| s[:codec_type] == 'video' } rescue {}
      audio_streams = video.audio_streams

      basename = File.basename(video.path)
      size = File.size(video.path) / 1048576.0
      bitrate = video.bitrate / 1024.0
      l1 = '%s (%.1f MB @ %.1f kbps)' % [basename, size, bitrate]

      vcodec = codec_format(video.video_codec)
      vprofile = " 10-bit" if vmeta[:profile] =~ /10/
      acodec = audio_streams.map{ |as| codec_format(as[:codec_name]) }.join(' + ')
      abps = audio_streams.map{ |as| '%.1f kbps' % (as[:bitrate] / 1024.0) }.join(' + ')

      w = video.width
      h = video.height
      duration = time_format(video.duration)
      fps = video.frame_rate
      vbps = video.video_bitrate
      if vbps == 0
        vbps = vmeta[:tags][:BPS].to_i rescue 0
      end
      av_bitrate = if vbps > 0
        '(%.1f kbps + %s)' % [vbps / 1024.0, abps]
      end
      l2 = '%s%s + %s - %dx%d - %s @ %.3f fps %s' % [vcodec, vprofile, acodec, w, h, duration, fps, av_bitrate]

      text = Draw.new
      text.font = FONT
      text.gravity = Magick::WestGravity
      text.pointsize = 24
      text.annotate(out, video.width - 10, IMG_HEADER / 2, 10, 10, l1)
      text.annotate(out, video.width - 10, IMG_HEADER / 2, 10, IMG_HEADER / 2, l2)

      puts "Writing to #{video.path}.jpg"
      out.write("#{video.path}.jpg")
    end

    def get_box(idx)
      return [idx * 2, 0, 2, 2] if idx < 2
      return [(idx - 10) * 2, 4, 2, 2] if idx >= 10
      [(idx - 2) % 4, (idx - 2) / 4 + 2, 1, 1]
    end

    def draw_with_shadow(format, out, w, h, x, y, text)
      format.fill = 'black'
      format.annotate(out, w, h, x+1, y, text)
      format.annotate(out, w, h, x-1, y, text)
      format.annotate(out, w, h, x, y+1, text)
      format.annotate(out, w, h, x, y-1, text)
      format.fill = 'white'
      format.annotate(out, w, h, x, y, text)
    end

    def time_format(sec)
      if sec > 600
        sec = sec.round
        '%d:%02d:%02d' % [sec / 3600, sec / 60 % 60, sec % 60]
      else
        '%02d:%02d.%03d' % [sec / 60 % 60, sec % 60, (sec * 1000) % 1000]
      end
    end

    def timestamp_format(sec)
      '%d:%02d:%02d' % [sec / 3600, sec / 60 % 60, sec % 60]
    end

    def codec_format(codec)
      case codec
      when 'h264' then 'H.264'
      when 'hevc' then 'H.265/HEVC'
      else codec.upcase
      end
    end
  end
end
