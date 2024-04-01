#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/inline"
gemfile(true) do
  source "https://rubygems.org"
  gem "rails", "7.1" # github: "rails/rails", branch: "main"
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

ActiveRecord::Base.establish_connection(DB_CONFIG.merge(database: "postgres"))
begin
  ActiveRecord::Base.connection.drop_database("playground")
rescue ActiveRecord::NoDatabaseError; end
ActiveRecord::Base.connection.create_database("playground")

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
    t.timestamps
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

    relation = Post.where("body ILIKE ?", "%hello%")
    expect(relation.to_a).to eq([post])
    _query, binds, prepared = Post.connection.send :to_sql_and_binds, relation.arel
    expect(binds.size).to eq 0
    expect(prepared).to eq false

    relation = Post.where(Post.arel_table['body'].matches("%hello%"))
    expect(relation.to_a).to eq([post])
    _query, binds, prepared = Post.connection.send :to_sql_and_binds, relation.arel
    expect(binds.size).to eq 0
    expect(prepared).to eq true

    relation = Post.where(Post.arel_table['body'].matches(ActiveRecord::Relation::QueryAttribute.new('body', "%hello%", ActiveRecord::Type::String.new)))
    expect(relation.to_a).to eq([post])
    _query, binds, prepared = Post.connection.send :to_sql_and_binds, relation.arel
    expect(binds.size).to eq 1
    expect(prepared).to eq true

    relation = Post.where("created_at > ?", 10.minutes.ago)
    expect(relation.to_a).to eq([post])
    _query, binds, prepared = Post.connection.send :to_sql_and_binds, relation.arel
    expect(binds.size).to eq 0
    expect(prepared).to eq false

    relation = Post.where(created_at: 10.minutes.ago..)
    expect(relation.to_a).to eq([post])
    _query, binds, prepared = Post.connection.send :to_sql_and_binds, relation.arel
    expect(binds.size).to eq 1
    expect(prepared).to eq true

    relation = Post.where(Post.arel_table['created_at'].gt(10.minutes.ago))
    expect(relation.to_a).to eq([post])
    _query, binds, prepared = Post.connection.send :to_sql_and_binds, relation.arel
    expect(binds.size).to eq 0
    expect(prepared).to eq true # <-- wild

    relation = Post.where(Post.arel_table['created_at'].gt(ActiveRecord::Relation::QueryAttribute.new('created_at', 10.minutes.ago, ActiveRecord::Type::DateTime.new)))
    expect(relation.to_a).to eq([post])
    _query, binds, prepared = Post.connection.send :to_sql_and_binds, relation.arel
    expect(binds.size).to eq 1
    expect(prepared).to eq true

    relation = Post.where("comments_count >= ?", 1)
    expect(relation.to_a).to eq([post])
    _query, binds, prepared = Post.connection.send :to_sql_and_binds, relation.arel
    expect(binds.size).to eq 0
    expect(prepared).to eq false

    relation = Post.where(Post.arel_table['comments_count'].gteq(1))
    expect(relation.to_a).to eq([post])
    _query, binds, prepared = Post.connection.send :to_sql_and_binds, relation.arel
    expect(binds.size).to eq 0
    expect(prepared).to eq true

    relation = Post.where(Post.arel_table['comments_count'].gteq(ActiveRecord::Relation::QueryAttribute.new('comments_count', 1, ActiveRecord::Type::Integer.new)))
    expect(relation.to_a).to eq([post])
    _query, binds, prepared = Post.connection.send :to_sql_and_binds, relation.arel
    expect(binds.size).to eq 1
    expect(prepared).to eq true

    # query = Post.where(Post.arel_table['body'].matches(Arel::Nodes::BindParam.new(ActiveRecord::Relation::QueryAttribute.new('body', "%hello%", ActiveRecord::Type::String.new))))
    # expect(query.to_a).to eq([post])
    #
    # query = Post.where(Post.arel_table['comments_count'].gteq(Arel::Nodes::BindParam.new()))
    # expect(query.count).to eq(1)
  end
end
