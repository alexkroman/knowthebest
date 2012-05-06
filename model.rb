set :database, ENV['DATABASE_URL'] || "postgres://test:test@localhost/knowthebest"

class Topic < Sequel::Model
  plugin :timestamps
  one_to_many :picks
  one_to_many :topics
  
  def display_name
    "Best #{self[:name]}".gsub(/\b('?[a-z])/) { $1.capitalize }
  end
  
  def self.featured
    Topic.eager_graph(:picks => [:votes]).filter(:user_id => 1).order(:created_at.desc)
  end
  
end

class Pick < Sequel::Model
  plugin :timestamps
  many_to_one :topic
  one_to_many :votes, :eager => [:user]
  one_to_many :comments, :eager => [:user], :order => [:created_at.asc]
  
  def referral_url
    return '' unless url
    CGI.unescape(url).sub('=ws','=scriptfurnace-20')
  end

end

class User < Sequel::Model
  plugin :timestamps
  one_to_many :votes
    
  def self.find(identifier)
    u = self[:identifier => identifier]
    u = create(:identifier => identifier) if u.nil?
    return u
  end
  
end

class Vote < Sequel::Model
  many_to_one :pick
  many_to_one :user
  many_to_one :topic
  
  def self.recent_bests
    eager_graph(:topic, :pick, :user).order(:created_at.desc)
  end
  
  def before_create
    self.user.votes_dataset.filter(:topic_id => topic[:id]).delete
    self.created_at = Time.now
  end
  
end

class Search
  def self.new(term)
    @results = Amazon::Ecs.item_search(term, {:response_group => 'Medium', :search_index => 'Blended'}).items[0..5].collect do |item|
      {:url => item.get('detailpageurl'), :title => item.get('title'), :image => item.get('mediumimage/url'), :from => 'Amazon'}
    end
    @results |= Google::Search::Web.new(:query => term).collect[0..0].collect do |item| 
      {:url => item.uri, :title => item.title, :image => "http://open.thumbshots.org/image.aspx?url=#{item.uri}", :from => 'Google Web'}
    end
    @results |= Google::Search::Local.new(:query => term).collect[0..5].collect do |item|
      {:url => item.uri, :title => item.title, :image => item.thumbnail_uri, :from => 'Google Local'}
    end
    @results |= Google::Search::Image.new(:query => term).collect[0..5].collect do |item|
      {:url => item.uri, :title => item.title, :image => item.thumbnail_uri, :from => 'Google Image'}
    end
  rescue
    @results
  end
end
