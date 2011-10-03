require 'erb'
require 'uri'

module Dropcaster
  #
  # Represents a podcast feed in the RSS 2.0 format
  #
  class Channel < DelegateClass(Hash)
    include HashKeys

    # Instantiate a new Channel object. +sources+ must be present and can be a String or Array
    # of Strings, pointing to a one or more directories or MP3 files.
    #
    # +options+ is a hash with all attributes for the channel. The following attributes are 
    # mandatory when a new channel is created:
    # 
    # * <tt>:title</tt> - Title (name) of the podcast
    # * <tt>:url</tt> - URL to the podcast
    # * <tt>:description</tt> - Short description of the podcast (a few words)
    # * <tt>:enclosure_base</tt> - Base URL for enclosure links
    #
    def initialize(sources, options)
      super(Hash.new)

      # Assert mandatory options
      [:title, :url, :description, :enclosure_base].each{|attr|
        raise MissingAttributeError.new(attr) if options[attr].blank?
      }
      
      self.merge!(options)
      self.categories = Array.new
      @source_files = Array.new

      if (sources.respond_to?(:each)) # array
        sources.each{|src|
          add_files(src)
        }
      else
        # single file or directory
        add_files(src)
      end

      @index_template = ERB.new(File.new(File.join(File.dirname(__FILE__), '..', '..', 'templates', 'channel.rss.erb')), 0, "%<>")
    end

    #
    # Returns this channel as an RSS representation. The actual rendering is done with the help
    # of an ERB template. By default, it is expected as ../../templates/channel.rss.erb (relative)
    # to channel.rb.
    #
    def to_rss
      @index_template.result(binding)
    end

    #
    # Returns all items (episodes) of this channel, ordered by newest-first.
    #
    def items
      all_items = Array.new
      @source_files.each{|src|
        item = Item.new(src)

        # set author and image_url from channel if empty
        item.tag.artist = self.author if item.artist.blank?
        item.image_url = self.image_url if item.image_url.blank?
        
        # construct absolute URL, based on the channel's enclosure_base attribute
        enclosure_base << '/' unless enclosure_base =~ /\/$/
        item.url = URI.join(URI.escape(enclosure_base), URI.escape(item.file_name))
        
        all_items << item
      }
      
      all_items.sort{|x, y| y.pub_date <=> x.pub_date}
    end

  private
    def add_files(src)
      if File.directory?(src)
        @source_files.concat(Dir.glob(File.join(src, '*.mp3')))
      else
        @source_files << src
      end
    end
  end
end
