class Event < ActiveRecord::Base
  set_table_name 'event'
  set_primary_keys :sid, :cid
  has_activity :by => "timestamp"
  has_one :importance, :class_name => 'Importance', :foreign_key => [:sid, :cid], :dependent => :destroy
  has_many :comments, :foreign_key => [:sid, :cid], :dependent => :destroy
  belongs_to :sensor, :class_name => "Sensor", :foreign_key => 'sid'
  belongs_to :iphdr, :class_name => "Iphdr", :foreign_key => [:sid, :cid], :dependent => :destroy
  belongs_to :tcphdr, :class_name => "Tcphdr", :foreign_key => [:sid, :cid], :dependent => :destroy
  belongs_to :icmphdr, :class_name => "Icmphdr", :foreign_key => [:sid, :cid], :dependent => :destroy
  belongs_to :udphdr, :class_name => "Udphdr", :foreign_key => [:sid, :cid], :dependent => :destroy
  belongs_to :data_info, :class_name => 'Data_Info', :foreign_key => [:sid, :cid], :dependent => :destroy
  belongs_to :opt, :class_name => 'Opt', :foreign_key => [:sid, :cid], :dependent => :destroy
  belongs_to :sig, :class_name => "Signature", :foreign_key => 'signature' #, :dependent => :destroy
  belongs_to :sig_reference, :class_name => "SigReference", :foreign_key => 'signature', :dependent => :destroy


  def self.all_uniq_signatures_like(sig_name)
    find(:all, :include => [:sig], :conditions => ['signature.sig_name LIKE ?', "%#{sig_name}%"]).map{ |event| event.sig.sig_name }.uniq.sort
  end

  def self.event_count_for(severity)
    count(:include => :sig, :conditions => ['signature.sig_priority = ?', severity])
  end

  def self.all_for_category(options = {})
    find(:all, :include => [:sensor, :iphdr, {:sig => :sig_class }, :comments], :conditions => ["signature.sig_class_id = ?", options[:c_id]], :order => 'timestamp DESC')
  end

  def self.events_for_sensor(s)
    find(:all, :conditions => ['sid = ?', s.id])
  end

  def self.livelook(severity)
    if severity
      if severity == 'All'
        self.find(:all, :limit => 20, :order => 'timestamp DESC', :include => [:sig, :sensor, :iphdr])
      else
        self.find(:all, :limit => 20, :order => 'timestamp DESC', :include => [:sig, :sensor, :iphdr], :conditions => ['signature.sig_priority = ?', severity])
      end
    else
      self.find(:all, :limit => 20, :order => 'timestamp DESC', :include => [:sig, :sensor, :iphdr])
    end
  end

  def self.events_for_severity(severity)
    self.find(:all, :order => 'timestamp DESC', :include => [:sig, :sensor, :iphdr], :conditions => ['signature.sig_priority = ?', severity])
  end

  def self.run_daily_report
    @events = self.find(:all, :conditions => ['timestamp >= ?', Chronic.parse('one day ago')])
    report = Report.new(:title => "Daily Report For #{Chronic.parse('one day ago')}", :rtype => 'daily', :from_time => "#{Chronic.parse('one day ago')}", :to_time => "#{Time.now}")
    if report.save!
      Pdf_for_email.make_pdf(report, @events)
      ReportMailer.deliver_daily_report(report, @events)
    end
  end

  def self.run_weekly_report
    @events = self.find(:all, :conditions => ['timestamp >= ?', Chronic.parse('one week ago')])
    report = Report.new(:title => "Weekly Report For #{Chronic.parse('one week ago')}", :rtype => 'weekly', :from_time => "#{Chronic.parse('one week ago')}", :to_time => "#{Time.now}")
    if report.save!
      Pdf_for_email.make_pdf(report, @events)
      ReportMailer.deliver_weekly_report(report, @events)
    end
  end

  def self.run_monthly_report
    @events = self.find(:all, :conditions => ['timestamp >= ?', Chronic.parse('one month ago')])
    report = Report.new(:title => "Monthly Report For #{Chronic.parse('one month ago')}", :rtype => 'monthly', :from_time => "#{Chronic.parse('one month ago')}", :to_time => "#{Time.now}")
    if report.save!
      Pdf_for_email.make_pdf(report, @events)
      ReportMailer.deliver_monthly_report(report, @events)
    end
  end

  def source_ip
    IPAddr.new_ntoh([self.iphdr.ip_src].pack('N'))
  rescue => e
    false
  end

  def destination_ip
    IPAddr.new_ntoh([self.iphdr.ip_dst].pack('N'))
  rescue => e
    false
  end

  def self.find_event_count_for?(sig_class)
    if self.find(:all, :include => :sig, :conditions => ["signature.sig_class_id = #{sig_class}"]).size
      return self.find(:all, :include => :sig, :conditions => ["signature.sig_class_id = #{sig_class}"]).size
    else
      return 0
    end
  end
  
  def solera_call(user, type)
    call = case type
      when "sonar" then "https://#{self.sensor.solera_api_host}/deepsee_reports?user=#{user.solera_api_user}&password=#{user.solera_api_pass}#pathString=%2Ftimespan%2F#{Chronic.parse('1 minutes before', :now => self.timestamp).getutc.strftime('%m.%d.%Y.%I.%M.%S')}.#{Chronic.parse('1 minutes after', :now => self.timestamp).getutc.strftime('%m.%d.%Y.%I.%M.%S')}%2Fipv4_address%2F#{self.source_ip}_and_#{self.destination_ip}%2F;reportIndex=0"
      when "pcap" then "https://#{self.sensor.solera_api_host}/ws/pcap?method=deepsee&user=#{user.solera_api_user}&password=#{user.solera_api_pass}&path=%2Ftimespan%2F#{self.timestamp.getutc.strftime('%m.%d.%Y.%I.%M.%S')}.#{self.timestamp.getutc.strftime('%m.%d.%Y.%I.%M.%S')}%2Fipv4_address%2F#{self.source_ip}_and_#{self.destination_ip}%2Fdata.pcap"
    end
    return call
  end

end
