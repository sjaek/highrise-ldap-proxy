require 'rubygems'
require 'uri'
gem 'activeresource'
require 'active_resource'

module ActiveResource
  
  class SiteConfig
    @@siteconfig = nil;

    def self.config
        @@siteconfig
    end
    def self.config=(val)
        @@siteconfig = val
    end

    def site 
      Thread.current[:parsedsite] = URI.parser.parse(_site) unless Thread.current[:parsedsite]
      Thread.current[:parsedsite]
    end
      
    def _site 
      if (Thread.current[:connection]) 
          @@siteconfig.gsub("{{SUBDOMAIN}}", Thread.current[:connection].username).gsub("{{APIKEY}}", Thread.current[:connection].password)
      else
          @@siteconfig
      end
    end
  end
  
  class Base 
    class << self 
        alias :_connection_aliased :connection 
    end
      
    self.format = ActiveResource::Formats::XmlFormat
    @@siteconfig = ActiveResource::SiteConfig.new
    def self.site 
      @@siteconfig.site
    end
    def self.user
      self.site.user
    end

    def self.password
      self.site.password
    end
  
    def self.connection(refresh = true) 
      self._connection_aliased(true)
    end
  end
  

end

module Highrise
  module Pagination
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def find_all_across_pages(options = {})
        records = []
        each(options) { |record| records << record }
        records
      end

      def each(options = {})
        options[:params] ||= {}
        options[:params][:n] = 0

        loop do
          if (records = self.find(:all, options)).any?
            records.each { |record| yield record }
            options[:params][:n] += records.size
          else
            break # no people included on that page, thus no more people total
          end
        end
      end
    end
  end

  
  
  class Base < ActiveResource::Base
  
  end
  
  # Abstract super-class, don't instantiate directly. Use Kase, Company, Person instead.
  class Subject < Base
    def notes
      Note.find_all_across_pages(:from => "/#{self.class.collection_name}/#{id}/notes.xml")
    end

    def emails
      Email.find_all_across_pages(:from => "/#{self.class.collection_name}/#{id}/emails.xml")
    end

    def upcoming_tasks
      Task.find(:all, :from => "/#{self.class.collection_name}/#{id}/tasks.xml")
    end
  end
  
  class Kase < Subject
    # find(:all, :from => :open)
    # find(:all, :from => :closed)  
    
    def close!
      self.closed_at = Time.now.utc
      save
    end
  end
  
  class Person < Subject
    include Pagination
    
    def self.find_all_across_pages_since(time)
      find_all_across_pages(:params => { :since => time.to_s(:db).gsub(/[^\d]/, '') })
    end
    
    def company
      Company.find(company_id) if company_id
    end
    
    def name
      "#{first_name} #{last_name}".strip
    end
  end
  
  class Company < Subject
    include Pagination

    def self.find_all_across_pages_since(time)
      find_all_across_pages(:params => { :since => time.to_s(:db).gsub(/[^\d]/, '') })
    end

    def people
      Person.find(:all, :from => "/companies/#{id}/people.xml")
    end
  end
  
  class Note < Base
    include Pagination

    def comments
      Comment.find(:all, :from => "/notes/#{id}/comments.xml")
    end
  end
  
  class Email < Base
    include Pagination

    def comments
      Comment.find(:all, :from => "/emails/#{email_id}/comments.xml")
    end
  end
  
  class Comment < Base
  end

  class Task < Base
    # find(:all, :from => :upcoming)
    # find(:all, :from => :assigned)  
    # find(:all, :from => :completed)  

    def complete!
      load_attributes_from_response(post(:complete))
    end
  end

  class User < Base
    def join(group)
      Membership.create(:user_id => id, :group_id => group.id)
    end
  end

  class Group < Base
    # Auto-loads the users collection
  end
  
  class Membership < Base
  end
end