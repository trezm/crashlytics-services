=begin

Create bitbucket issues for new crashes.

User inputs are password and project url.
User name and project name will be parsed from project url.

Project url is in format https://bitbucket.org/user_name/project_name

Ref API : https://confluence.atlassian.com/display/BITBUCKET/issues+Resource#issuesResource-POSTanewissue
API Test : http://restbrowser.bitbucket.org/

=end

class Service::Bitbucket < Service::Base

  title "Bitbucket"

  string :username, :placeholder => 'username',
    :label => 
      'Your credentials will be encrypted. ' \
      'However, we strongly recommend that you create a separate ' \
      'Bitbucket account for integration with Crashlytics. ' \
      'Limit the account\'s write access to the repo you want ' \
      'to post issues to.' \
      '<br /><br />' \
      'Your Bitbucket username:'
  password :password, :placeholder => 'password',
     :label => 'Your Bitbucket password:'
  string :repo_owner, :placeholder => "repository owner",
     :label => 'The owner of your repo:'
  string :repo, :placeholder => "repository",
     :label => 'The name of your repo:'

  page "Username", [:username]
  page "Password", [:password]
  page "Repository Owner (if different from Username)", [:repo_owner]
  page "Repository", [:repo]
  

  def receive_verification(config, _)
    username = config[:username]
    repo_owner = config[:repo_owner]
    if repo_owner == nil or repo_owner.length == 0
      repo_owner = username
    repo = config[:repo]
    http.ssl[:verify] = true
    http.basic_auth username, config[:password]

    resp = http_get build_url(repo_owner, repo)

    if resp.status == 200
      [true, "Successfully verified Bitbucket settings"]
    else
      log "HTTP Error: status code: #{ resp.status }, body: #{ resp.body }"
      [false, "Oops! Please check your settings again."]
    end
  rescue => e
    log "Rescued a verification error in bitbucket: (repo=#{config[:repo]}) #{e}"
    [false, "Oops! Is your repository url correct?"]
  end

  def receive_issue_impact_change(config, payload)
    username = config[:username]
    repo_owner = config[:repo_owner]
    if repo_owner == nil or repo_owner.length == 0
      repo_owner = username
    repo = config[:repo]
    http.ssl[:verify] = true
    http.basic_auth username, config[:password]

    users_text = ""
    crashes_text = ""

    if payload[:impacted_devices_count] == 1
      users_text = "This issue is affecting at least 1 user who has crashed "
    else
      users_text = "This issue is affecting at least #{ payload[:impacted_devices_count] } users who have crashed "
    end

    if payload[:crashes_count] == 1
      crashes_text = "at least 1 time.\n\n"
    else
      "at least #{ payload[:crashes_count] } times.\n\n"
    end

    issue_description = "Crashlytics detected a new issue.\n" + \
      "#{ payload[:title] } in #{ payload[:method] }\n\n" + \
      users_text + \
      crashes_text + \
      "More information: #{ payload[:url] }"

    post_body = {
      :kind => 'bug',
      :title => payload[:title] + ' [Crashlytics]',
      :content => issue_description
    }

    resp = http_post build_url(repo_owner, repo) do |req|
      req.body = post_body
    end

    if resp.status != 200
      raise "Bitbucket issue creation failed: #{ resp.status }, body: #{ resp.body }"
    end

    { :bitbucket_issue_id => JSON.parse(resp.body)['local_id'] }
  end

  def build_url(repo_owner, repo)
    url_prefix = 'https://bitbucket.org/api/1.0/repositories'
    url = "#{url_prefix}/#{repo_owner}/#{repo}/issues"
    puts url
    url
  end
end
