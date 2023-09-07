#!/usr/bin/env ruby
# frozen_string_literal: true

# Inspired by https://greg.molnar.io/blog/a-single-file-rails-application/
# Most of the work here went into constructing the DATABASE_URL and Postgres stuff.

require "bundler/inline"
gemfile(true) do
  source "https://rubygems.org"
  git_source(:github) { |repo| "https://github.com/#{repo}.git" }
  gem "rails", github: 'rails/rails', branch: "main"
  gem "rspec-rails"
  gem "pg"
  gem "sqlite3"
end

# DB_CONFIG = {
#   adapter: 'sqlite3',
#   database: "playground.sqlite3"
# }

DB_CONFIG = {
  adapter: "postgresql",
  database: "playground",
  host: "localhost",
  username: "postgres",
  pool: 99,
}

require 'rails/all'
require "logger"

# While we can use `establish_connection` to create individual connections,
# To set up real Active Record connection pools and all other configuration
# Rails requires that we either use an explicit `config/database.yml` file,
# or we can pack all of the database configuration into a single DATABASE_URL:
ENV['DATABASE_URL'] = lambda do |kwargs|
  if kwargs[:adapter] == 'sqlite3'
    "sqlite3:#{kwargs[:database]}"
  else
    URI("").tap do |uri|
      uri.scheme = kwargs[:adapter]
      uri.user = kwargs[:username]
      uri.password = kwargs[:password]
      uri.host = kwargs[:host]
      uri.port = kwargs[:port]
      uri.path = "/#{kwargs[:database]}"

      params = kwargs.without(:adapter, :host, :username, :password, :port, :database)
      uri.query = URI.encode_www_form(params) if params.any?
    end.to_s
  end
end.call(DB_CONFIG)
puts ENV['DATABASE_URL']

Rails.logger = ActiveRecord::Base.logger = Logger.new(STDOUT)

class App < Rails::Application
  config.root = __dir__
  config.consider_all_requests_local = true
  config.secret_key_base = 'i_am_a_secret'
  config.hosts << "www.example.com"
  config.eager_load = false
  config.active_support.cache_format_version = 7.0

  routes.append do
    root to: 'examples#index'
  end
end

# Drop an existing database
# ActiveRecord::Base.establish_connection(DB_CONFIG.merge(database: "postgres", schema_search_path: "public"))
# ActiveRecord::Base.connection.drop_database(DB_CONFIG[:database])
# ActiveRecord::Base.remove_connection

begin
  ActiveRecord::Base.establish_connection(DB_CONFIG)

  ActiveRecord::Schema.define do
    create_table :posts, force: true do |t|
      t.text :body
      t.integer :comments_count, default: 0
    end

    create_table :comments, force: true do |t|
      t.integer :post_id
    end
  end

  ActiveRecord::Base.remove_connection
rescue ActiveRecord::NoDatabaseError
  raise if retried ||= nil

  ActiveRecord::Base.establish_connection(DB_CONFIG.merge(database: "postgres", schema_search_path: "public"))
  ActiveRecord::Base.connection.create_database(DB_CONFIG[:database])
  ActiveRecord::Base.remove_connection

  retried = true
  retry
end

class Post < ActiveRecord::Base
  has_many :comments
end

class Comment < ActiveRecord::Base
  belongs_to :post, counter_cache: true
end

class ExamplesController < ActionController::Base
  def index
    Post.where(Post.arel_table['body'].matches(Arel::Nodes::BindParam.new(ActiveRecord::Relation::QueryAttribute.new('body', "%hello%", ActiveRecord::Type::String.new)))).to_a
    Post.where(Post.arel_table['body'].matches(Arel::Nodes::BindParam.new(ActiveRecord::Relation::QueryAttribute.new('body', "%hello%", ActiveRecord::Type::String.new)))).to_a
    Post.where(Post.arel_table['body'].matches(Arel::Nodes::BindParam.new(ActiveRecord::Relation::QueryAttribute.new('body', "%goodbye%", ActiveRecord::Type::String.new)))).to_a

    render inline: 'Hi!'
  end
end

App.initialize!

require 'rspec/rails'
require "rspec/autorun"

RSpec.describe "WelcomeController", type: :request do
  it 'will render the index' do
    post = Post.create!(body: "hello world")
    post.comments.create
    post.comments.create

    get "/"
    expect(response.body).to include("Hi!")
  end
end
