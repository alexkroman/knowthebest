require 'settings'

before do
  redirect 'http://allthebests.com', 301 if env['SERVER_NAME'] == 'www.allthebests.com'
  @user = User[session[:user_id]]
  @token_url = "http://" + env['HTTP_HOST'] + '/login?return=' + CGI.escape(env['REQUEST_URI'])
  @page_title = "allthebests | discover the best"
  @meta_description = "Our community ranks the best products and services in a variety of categories"
  @popular_bests = Topic.featured.limit(6)
  @leaders = []
  Vote.select(:count.sql_function(:id), :user_id).filter(:created_at > Time.now - (86400 * 7)).group(:user_id).order(:count.desc).limit(5).each do |x|
    @leaders << {:points => x[:count] * 9, :user => User[x[:user_id]]}
  end
end

get '/about' do
  haml :about
end

post '/login' do
  openid_user = get_user(params[:token])
  user = User.find(openid_user[:identifier])
  user[:nickname] = openid_user[:nickname]
  user[:email] = openid_user[:email]
  user.save
  session[:user_id] = user[:id]
  redirect params[:return]
end

get '/new' do
  haml :new
end

get '/logout' do
  session.clear and redirect '/'
end

get '/' do
  @p = (params[:p] ||= 1).to_i
  @results = Vote.recent_bests.paginate(@p, 15)
  haml :index
end

get '/for/:nickname' do
  @for = User[:nickname => params[:nickname]]
  @page_title = @for[:nickname] + "'s bests | allthebests"
  @results = Vote.recent_bests.filter(:user_id => @for[:id])
  haml :users
end

get '/find' do
  @q = params[:q]
  @results = Vote.eager_graph(:topic, :pick, :user).filter(@q.downcase.split(' ').collect {|x| [:lower.sql_function(:topic__name), /#{x}/] }.sql_expr | @q.downcase.split(' ').collect {|x| [:lower.sql_function(:title), /#{x}/] }.sql_expr)
  haml :find
end

post '/pick' do
  @pick = Pick.find_or_create(:topic_id => params[:topic_id], :title => params[:item][:title], :image => params[:item][:image], :url => params[:item][:url])  
  @user.add_vote(:pick_id => @pick[:id], :comment => params[:comment], :topic_id => @pick.topic_id)
  redirect "/"
end

get '/look/:topic_id' do
  @topic = Topic[params[:topic_id]]
  haml :ask
end

get '/search/:topic_id' do
  @topic = Topic[params[:topic_id]]
  @q = params[:q]
  @results = []
  @initial_result = Search.new(@q).reverse
  @results.fill(nil, 0..@initial_result.size-1).collect! {|x| {:pick => @initial_result.pop, :votes => {:topic_id => @topic.id}} }
  haml :ask
end

get '/quick' do
  query = params[:term].downcase.split(' ').collect {|x| [:lower.sql_function(:name), /#{x}/] }.sql_expr
  Vote.eager_graph(:topic, :pick).filter(query).limit(20).collect{|x| x[:topic][:name]}.uniq.sort.to_json  
end

post '/go' do
  @pick = Topic.find_or_create(:slug => params[:q].to_slug, :name => params[:q])
  redirect "/#{@pick[:slug]}"
end

get '/style.css' do
  content_type "text/css"
  sass :style, :style => :compact
end

['/urllist.txt','/sitemap.txt'].each do |path|
  get path do
    content_type "text/plain"
    Topic.collect{|x| "http://allthebests.com/#{x[:slug]}\n"}
  end
end

get '/:name' do
  @topic = Topic[:slug => params[:name]]
  @picks_in_order = Vote.distinct(:pick_id).eager_graph(:topic, :pick, :user).filter(:votes__topic_id => @topic.id).sort{|b,a| Vote.filter(:pick_id => a[:votes][:pick_id]).count <=> Vote.filter(:pick_id => b[:votes][:pick_id]).count }
  redirect "/look/#{@topic.id}" if @picks_in_order.size == 0
  @votes = Vote.filter(:topic_id => @topic.id).order(:created_at.asc).all
  @page_title = "Best " + @topic[:name] + " | allthebests"
  @meta_description = "The best #{@topic[:name]} as voted by our community: " + @topic.picks.collect{|x| x.title }.join(", ")
  haml :detail
end

private

def get_user(token)
  u = URI.parse('https://rpxnow.com/api/v2/auth_info')
  req = Net::HTTP::Post.new(u.path)
  req.set_form_data({'token' => token, 'apiKey' => 'aaf3979e6d51b8cc16886feef6c868ec6ce982dd', 'format' => 'json', 'extended' => 'true'})
  http = Net::HTTP.new(u.host,u.port)
  http.use_ssl = true if u.scheme == 'https'
  json = JSON.parse(http.request(req).body)
  
  if json['stat'] == 'ok'
    identifier = json['profile']['identifier']
    nickname = json['profile']['preferredUsername']
    nickname = json['profile']['displayName'] if nickname.nil?
    email = json['profile']['email']
    {:identifier => identifier, :nickname => nickname, :email => email}
  else
    raise LoginFailedError, 'Cannot log in. Try another account!' 
  end
end