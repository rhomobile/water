require 'rho/rhocontroller'

class SiteController < Rho::RhoController
  
  def map 
    @annotations=[]
    @sites = Site.find :all
    @lat=GeoLocation.latitude
    @long=GeoLocation.longitude
 #   @annotations << {:latitude => @lat, :longitude => @long, :title => "Current location", :subtitle => ""}
    @sites.each do |x|
      @annotations << {:latitude=>x.LatitudeMeasure.to_f,:longitude=>x.LongitudeMeasure.to_f,:title=>x.MonitoringLocationName,
                      :url=>"http://localhost:8080/app/Site/show?id="+x.object+"&back=map"}
    end
    map_params = {
       :settings => {:map_type => "hybrid",:region => [@lat, @long, 0.2, 0.2],
                     :zoom_enabled => true,:scroll_enabled => true,:shows_user_location => true,
                     :api_key => 'Google Maps API Key'},
       :annotations => @annotations
    }
    MapView.create map_params
    redirect :action=>:index
  end
  
  #GET /Site
  def index
    if SyncEngine::logged_in == 0
       SyncEngine.login("adam", "password", (url_for :controller=>"Settings",:action => :login_callback) )
       redirect :controller=>"Settings", :action => :wait
    end
    
    # returns true if system location system is up and acquired position, nevertheless sometimes still returns 0,0
    if GeoLocation.known_position? && (GeoLocation.latitude!=0.0 && GeoLocation.longitude!=0.0)
      @lat=GeoLocation.latitude
      @long=GeoLocation.longitude
      puts "@lat=#{@lat} @long=#{@long}"
            
      # since the last reading
      puts "Rho::RhoConfig.LastLatitude.to_f =#{Rho::RhoConfig.LastLatitude.to_f}"
      distance_moved=haversine_distance(Rho::RhoConfig.LastLatitude.to_f,Rho::RhoConfig.LastLongitude.to_f,@lat,@long)
      puts "distance moved since last reading #{distance_moved}"

      Rho::RhoConfig.LastLatitude = @lat.to_s
      Rho::RhoConfig.LastLongitude = @long.to_s
    
      @radius=0.1
  
      @sites=Site.find(:all)
      puts "raw # of sites = #{@sites.length}"
      
      @distances={}
      @sites.each do |x|
        @distances[x.object]=haversine_distance(x.LatitudeMeasure.to_f,x.LongitudeMeasure.to_f,@lat,@long)
      end
      @sites=@sites.sort { |x,y| @distances[x.object]<=>@distances[y.object] }
      
      # reject ones that are too far away to not appear on map
      @sites=@sites.reject { |x| @distances[x.object] > 10.0 }
    
      if @params["search_params"].nil? and (distance_moved > @radius/2 or @sites.nil? or @sites.size==0)           
        Site.search(
        :from => 'search',
        :search_params => { :lat => @lat, :long => @long, :radius=>@radius },
        :max_results => 100,
        :callback => '/app/Site/search_callback')
      end
    else
      redirect :action => :unknown_location
    end
  end
  
  def search_callback    
    if (@params["status"] && @params["status"] == 'ok')
      WebView.navigate(url_for :action => :index,:query=>{:search_params => @params["search_params"]})
    end
  end

  # GET /Site/{1}
  def show
      @site = Site.find @params['id']
      render :action => :show, :back=>'/app/Site/map'
  end

  # GET /Site/new
  def new
    @site = Site.new
    render :action => :new
  end

  # GET /Site/{1}/edit
  def edit
    @site = Site.find(@params['id'])
    render :action => :edit
  end

  # POST /Site/create
  def create
    @site = Site.new(@params['site'])
    @site.save
    redirect :action => :index
  end

  # POST /Site/{1}/update
  def update
    @site = Site.find(@params['id'])
    @site.update_attributes(@params['site'])
    redirect :action => :index
  end

  # POST /Site/{1}/delete
  def delete
    @site = Site.find(@params['id'])
    @site.destroy
    redirect :action => :index
  end
  
  protected
  
  RAD_PER_DEG = 0.017453293  #  PI/180
  Rmiles = 3956           # radius of the great circle in miles
  def haversine_distance( lat1, lon1, lat2, lon2 )
    dlon = lon2 - lon1
    dlat = lat2 - lat1
    dlon_rad = dlon * RAD_PER_DEG
    dlat_rad = dlat * RAD_PER_DEG 
    lat1_rad = lat1 * RAD_PER_DEG
    lon1_rad = lon1 * RAD_PER_DEG
    lat2_rad = lat2 * RAD_PER_DEG 
    lon2_rad = lon2 * RAD_PER_DEG
    a = (Math.sin(dlat_rad/2))**2 + Math.cos(lat1_rad) * Math.cos(lat2_rad) * (Math.sin(dlon_rad/2))**2
    c = 2 * Math.atan2( Math.sqrt(a), Math.sqrt(1-a))
    dMi = Rmiles * c          # delta between the two points in miles
  end

  
end
 
 
 
 
 
 

