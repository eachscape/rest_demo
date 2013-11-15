#!/usr/bin/env ruby
require 'json'
require 'mongo'
require 'sinatra'
require 'sinatra/namespace'


## Database Setup
# Setup a connection to MongoDB
db = begin
  if ENV['MONGODB_URI']
    # from_uri will implicitly use MONGODB_URI; we just need to tell it which db to use
    db = ENV['MONGODB_URI'].split('/').last
    Mongo::Connection.from_uri.db(db)
  # Dev mode (use the local database server with the default db name)
  else
    Mongo::Connection.new.db('rest_demo')
  end
end
# Created a collection for our demo records, limited to 50MB or 1,000 records
# (old records will automatically be deleted to make room)
people = db.create_collection('people',:capped => true, :size => (50 * 1024), :max => 1000)


# Remaps the BSON _id in a MongODB record into an id key, which is just BSON ID as a string
# eg. {_id: {$oid: '123'}, name: 'Joe'} => {id: '123', name: 'Joe'}
def remap_id!(record)
  record['id'] = record.delete('_id').to_s
  record
end


## The REST API
namespace '/api/v1' do
  # Returns all our records, as a JSON array
  get '/people' do
    content_type 'application/json'
    all_people = people.find.to_a
    all_people.each { |p| remap_id!(p) }
    JSON.pretty_generate(all_people) + "\r\n"
  end

  # Get a specific person by ID
  get '/people/:id' do
    person = people.find_one(_id: BSON::ObjectId(params[:id]))
    if person
      content_type 'application/json'
      remap_id!(person)
      JSON.pretty_generate(person)
    else
      status 404
      body "Could not person with ID #{params[:id]}"
    end
  end

  # Adds a new record, based on the POST parameters
  # Returns the ID of the new record, or an error
  post '/people' do
    name = params[:name].strip
    # Validations
    unless name
      status 400
      body 'Name must not be blank.'
    end
    unless name.size < 50
      status 400
      body 'Name must be less than 50 characters.'
    end
    # Save the record, and return the ID
    people.insert(name: name).to_s
  end
end
