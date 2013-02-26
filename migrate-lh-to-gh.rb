# Created by Thomas Balthazar, Copyright 2009
# Edited by Steve Androulakis github.com/steveandroulakis
# This script is provided as is, and is released under the MIT license : http://www.opensource.org/licenses/mit-license.php
# more information here : http://suitmymind.com/2009/04/18/move-your-tickets-from-lighthouse-to-github/

require 'rubygems'
require 'lighthouse-api'
require 'yaml'
require 'uri'
require 'github_api'

# -----------------------------------------------------------------------------------------------
# --- Lighthouse configuration
LIGHTHOUSE_ACCOUNT      = 'user@email.com'
LIGHTHOUSE_API_TOKEN    = '1234abcd33333cacb70758d916bbda0f0d7fb3754'
LIGHTHOUSE_PROJECT_ID   = 90210
LIGHTHOUSE_TICKET_QUERY = "state:open"
# Specify an array of tags here, and only those tags will be migrated. If nil is specified, all the tags will be migrated
LIGHTHOUSE_TAGS_TO_KEEP = nil


# -----------------------------------------------------------------------------------------------
# --- Github configuration
GITHUB_LOGIN      = "steveandroulakis"
GITHUB_PASSWORD   = "xxxx"
GITHUB_PROJECT    = "x"

# -----------------------------------------------------------------------------------------------
# --- setup LH
Lighthouse.account  = 'accountname'
# Lighthouse.token    = LIGHTHOUSE_API_TOKEN
Lighthouse.email = "user@email.com"
Lighthouse.password = "yyyy"
project             = Lighthouse::Project.find(LIGHTHOUSE_PROJECT_ID)


# -----------------------------------------------------------------------------------------------
# --- get all the LH tickts, page per page (the LH API returns 30 tickets at a time)
page        = 1
tickets     = []
tmp_tickets = project.tickets(:q => LIGHTHOUSE_TICKET_QUERY, :page => page)
while tmp_tickets.length > 0
  tickets += tmp_tickets
  page+=1
  tmp_tickets = project.tickets(:q => LIGHTHOUSE_TICKET_QUERY, :page => page)
end
puts "#{tickets.length} will be migrated from Lighthouse to Github.\n\n"

# -----------------------------------------------------------------------------------------------
# --- for each LH ticket, create a GH issue, and tag it
tickets.each { |ticket|

  github = Github.new :login=>GITHUB_LOGIN, :password=>GITHUB_PASSWORD
  token_res = github.oauth.create 'scopes' => ['repo']
  token_res['token']

  # fetch the ticket individually to have the different 'versions'
  ticket = Lighthouse::Ticket.find(ticket.id, :params => { :project_id => LIGHTHOUSE_PROJECT_ID})
  
  # get the ticket versions/history
  versions = ticket.versions  
  
  # this is the assigned user name of the corresponding LH ticket  
  assignee = versions.last.assigned_user_name unless versions.last.attributes["assigned_user_name"].nil?  

  title = ticket.title.gsub(/^@/," @")
  body  = versions.first.body.gsub(/^@/," @") unless versions.first.body.nil? 
  body||=""
  
  # add the original LH ticket URL at the end of the body
  body+="\n\n[original LH ticket](#{ticket.url})"
  
  # add the number of attachments
  body+="\n\n This ticket has #{ticket.attachments_count} attachment(s)." unless ticket.attributes["attachments_count"].nil?

  # the first version contains the initial ticket body
  versions.delete_at(0) 

  issues = Github::Issues.new :oauth_token=>token_res['token']

  
  issue = issues.create('mytardis','mytardis', :title=>title, :body=>body)

  labels = Github::Issues::Labels.new :oauth_token=>token_res['token']
  comments = Github::Issues::Comments.new :oauth_token=>token_res['token']

  
  # add comments to the newly created GH issue
  versions.each { |version|
    # add the LH comment title to the comment
    comment = "**#{version.title.gsub(/^@/," @").gsub(/'/,"&rsquo;")}**\n\n"
    comment+=version.body.gsub(/^@/," @").gsub(/'/,"&rsquo;") unless version.body.nil?
    comment+="\n\n by " + version.user_name.gsub(/^@/," @").gsub(/'/,"&rsquo;") unless version.user_name.nil?
    
    comments.create('mytardis','mytardis', issue['number'], :body=>comment)
  }  
  
  # here you can specify the labels you want to be applied to your newly created GH issue
  # preapare the labels for the GH issue
  gh_labels = []
  begin
    lh_tags = ticket.tags
    # only migrate LIGHTHOUSE_TAGS_TO_KEEP tags if specified
    lh_tags.delete_if { |tag| !LIGHTHOUSE_TAGS_TO_KEEP.include?(tag) } unless LIGHTHOUSE_TAGS_TO_KEEP.nil?
    # these are the tags of the corresponding LH ticket, replace @ by # because @ will be used to tag assignees in GH
    gh_labels += lh_tags.map { |tag| tag.gsub(/^@/,"#") }  
    gh_labels << "milestone-" + ticket.milestone_title unless ticket.attributes["milestone_title"].nil? # this is the milestone title of the corresponding LH ticket
    gh_labels << "assignee-" + assignee unless assignee.nil?
    gh_labels << "state- " + ticket.state # this is the state of the corresponding LH ticket
    gh_labels << "from-lighthouse" # this is a label that specify that this GH issue has been created from a LH ticket    
  rescue NoMethodError

  end
  
  # tag the issue
  gh_labels.each { |label|
    # labels containing . do not work ... -> replace . by •
    label.gsub!(/\./,".")
    puts label
    begin
      
      labels.create('mytardis','mytardis', :name=>label, :color=>"FFFFFF")
    rescue Github::Error::UnprocessableEntity
      puts label + " exists, skipping creation"
    end
    
    labels.add('mytardis','mytardis', issue['number'], label)

  }

}
