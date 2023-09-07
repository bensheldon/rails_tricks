#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/inline"
gemfile(true) do
  source "https://rubygems.org"
  gem "activerecord", "~> 7.0"
  gem "rspec"
  gem "pg"
end

require "active_record"
require "logger"

DB_CONFIG = {
  adapter: "postgresql",
  database: "postgres",
  host: "localhost",
  username: "postgres",
}

ActiveRecord::Base.establish_connection(DB_CONFIG)

ActiveRecord::Base.establish_connection(DB_CONFIG.merge(database: "postgres", ))
ActiveRecord::Base.connection.drop_database("playground")
# ActiveRecord::Base.connection.create_database("playground")

ActiveRecord::Base.establish_connection(
  adapter: "postgresql",
  database: "playground",
  host: "localhost",
  username: "postgres",
)
ActiveRecord::Base.logger = Logger.new(STDOUT)

ActiveRecord::Schema.define do
  create_table :posts, force: true do |t|
    t.text :body
    t.integer :comments_count, default: 0
  end

  create_table :comments, force: true do |t|
    t.integer :post_id
  end
end

class Post < ActiveRecord::Base
  has_many :comments
end

class Comment < ActiveRecord::Base
  belongs_to :post, counter_cache: true
end

require "rspec/autorun"
RSpec.describe "Bind Params" do
  it 'will bind Arel queries' do
    post = Post.create!(body: "hello world")
    post.comments.create
    post.comments.create

    result = Post.where(Post.arel_table['body'].matches(Arel::Nodes::BindParam.new(ActiveRecord::Relation::QueryAttribute.new('body', "%hello%", ActiveRecord::Type::String.new))))
    expect(result.to_a).to eq([post])

    result = Post.where(Post.arel_table['body'].matches(Arel::Nodes::BindParam.new(ActiveRecord::Relation::QueryAttribute.new('body', "%hello%", ActiveRecord::Type::String.new))))
    expect(result.to_a).to eq([post])

    result = Post.where(Post.arel_table['comments_count'].gteq(Arel::Nodes::BindParam.new(ActiveRecord::Relation::QueryAttribute.new('comments_count', 1, ActiveRecord::Type::Integer.new))))
    expect(result.count).to eq(1)
  end
end
