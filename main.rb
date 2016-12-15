#!/usr/bin/env ruby

require 'dotenv'
Dotenv.load
require 'koala'
require 'httparty'

$stdout.sync = true

def send_post(post, author_name, author_handle, author_pic, author_link)

  puts post
  puts "\n"

  attachments = [
    {
      pretext: post['permalink_url'],
      author_icon: author_pic,
      author_name: author_name,
      author_subname: '@' + author_handle,
      author_link: author_link,
      #color: '#3B5998', #fb blue
      ts: DateTime.parse(post['created_time']).strftime('%s')
    }
  ]

  if post['message'] && post['story']
    attachments[0].merge!({
      title: post['story'],
      text: post['message']
    })
  else
    attachments[0].merge!({
      text: post['message'] || post['story'],
    })
  end


  case post['status_type']
  when 'added_photos'
    attachments[0].merge!({
      image_url: post['full_picture'],
      from_url: post['permalink_url']
    })

  when 'added_video'
    attachments += [
      {
        title: "<#{post['source']}|Click to see video>",
        title_link: post['source'],
        image_url: post['full_picture']
      }
    ]

  when 'shared_story'
    attachments += [
      {
        title: post['name'],
        title_link: post['link'],
        text: post['description'],
        thumb_url: post['picture']
      }
    ]
  end

  HTTParty.post(ENV['SLACK_INCOMING_WEBHOOK'], body: {
    username: 'Facebook',
    icon_url: 'https://facebookbrand.com/wp-content/themes/fb-branding/prj-fb-branding/assets/images/fb-art.png',
    channel: ENV['SLACK_CHANNEL'],
    attachments: attachments,
  }.to_json)

end

puts 'Starting'

oauth = Koala::Facebook::OAuth.new(ENV['FACEBOOK_CLIENT_ID'], ENV['FACEBOOK_CLIENT_SECRET'], nil)
k = Koala::Facebook::API.new(oauth.get_app_access_token)

last_post = Time.now.to_i

while true
  fbpage = k.get_object("#{ENV['FACEBOOK_PAGE']}?fields=posts.since(#{last_post}){story,message,id,created_time,picture,full_picture,link,permalink_url,properties,source,description,caption,name,status_type},picture{url},name,username,link")

  if fbpage.include?('posts')
    fbpage['posts']['data'].reverse_each do |p|
      send_post(p, fbpage['name'], fbpage['username'], fbpage['picture']['data']['url'], fbpage['link'])

      last_post = [last_post, DateTime.parse(p['created_time']).to_time.to_i].max
    end
  end

  sleep 20
end

puts 'Finished'
