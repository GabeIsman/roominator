class Room < ActiveRecord::Base

  require 'yaml'

  EVENT_LENGTH_INCREMENT = 15.minutes.to_i
  REFRESH_PERIOD = 1.minute.to_i
  EVENT_TITLE = "Roomination"
  MASTER_CALENDAR_ID = "gisman%40rapleaf.com"
  STATUS_MEETING_NOW = 1
  STATUS_MEETING_SOON = 2
  STATUS_NO_MEETING = 3

  serialize :next_event
  serialize :current_event

  def add_or_extend(multiplier = 1)
    set_instance_variables
    notice_message = ""
    if @current_event.present?
      multiplier.times do
        if !@next_event || @current_event.end_time + EVENT_LENGTH_INCREMENT < @next_event.start_time
          @current_event.end_time = @current_event.end_time + EVENT_LENGTH_INCREMENT
        else
          notice_message = "Room already booked"
        end
      end
    else
      now = Time.now
      end_time = self.current_event ? Time._load(self.current_event[:end_time]) : now
      event_length = @next_event ? [@next_event.start_time - end_time, EVENT_LENGTH_INCREMENT * multiplier].min : EVENT_LENGTH_INCREMENT * multiplier
      @current_event = GCal4Ruby::Event.new(@service, {:calendar => @calendar,
                                              :title => EVENT_TITLE,
                                              :start_time => now.utc.xmlschema,
                                              :end_time => (now + event_length).utc.xmlschema,
                                              :where => @room_name})
      @current_event.attendees << {:status => "accepted", :email => self.calendar_id, :name => self.calendar_name, :role => "attendee"}
    end
    self.current_event = event_to_hash(@current_event)
    {:success => @current_event.save, :notice => notice_message}
  end

  # gets the current event happening in this room and and changes its end time to right now
  def cancel
    set_instance_variables
    if @current_event.present?
      @current_event.end_time = Time.now
      self.current_event = nil
      return @current_event.save
      self.save
    end
  end

  # sets the @room, @calendar, @event, and @next_event
  def set_instance_variables
    @service = ApplicationController::authenticate_to_gcal
    @calendar = @service.calendars.select{|cal| cal.id == MASTER_CALENDAR_ID}.first #grab the calendar to save to
    events = @calendar.events.select{|e| e.attendees.any?{|hash| hash[:email] == self.calendar_id} }
    currents = events.select{|e| e.start_time < Time.now && e.end_time > Time.now } #select the events who start-end span includes now
    @current_event = currents.first #there should only be one event at a time, if not we'll just ignore it
    self.current_event = event_to_hash(@current_event)
    next_events = events.select{|e| e.start_time > Time.now}
    @next_event = next_events.sort_by{|e| e.start_time}.first
    self.next_event = event_to_hash(@next_event)
    self.last_refresh = Time.now.to_i
    self.save
  end

  # returns false if there is currently an event happening on the calendar associated with params(:room_number) room
  # true otherwise
  def room_free
    !self.current_event
  end

  def get_status
    occupied_until = self.current_event ? Time._load(self.current_event[:end_time]) : nil
    occupied_next = self.next_event ? Time._load(self.next_event[:start_time]) : nil

    #infer the color status
    if self.current_event
      status = STATUS_MEETING_NOW
    elsif self.next_event && occupied_next < Time.now + 15.minutes.to_i
      status = STATUS_MEETING_SOON
    else
      status = STATUS_NO_MEETING
    end

    case status
      when STATUS_MEETING_NOW
        notice = "Busy until #{occupied_until.strftime("%R")}"
      when STATUS_MEETING_SOON
        notice = "Busy next at #{occupied_next.strftime("%R")}"
      when STATUS_NO_MEETING
        notice = occupied_next.nil? ? "Free forever" : "Free until #{occupied_next.strftime("%R")}"
    end

    notice = self.room_name + ": " + notice

    return {:status => status, :notice => notice}
  end

  def refresh_cache
    if self.last_refresh < Time.now.to_i
      #set_instance_variables
    end
  end

  def event_to_hash(event)
    event ? {:start_time => event.start_time._dump, :end_time => event.end_time._dump, :title => event.title} : nil
  end

  def db_cancel
    self.current_event = nil
    self.save
  end

  def db_add_or_extend(multiplier)
    now = Time.now
    #end_time = now #self.current_event ? Time._load(self.current_event[:end_time]) : now
    event_length = EVENT_LENGTH_INCREMENT#self.next_event ? [Time._load(self.next_event[:start_time]) - end_time, EVENT_LENGTH_INCREMENT * multiplier].min : EVENT_LENGTH_INCREMENT * multiplier
    if self.current_event
      self.current_event[:end_time] = (Time._load(self.current_event[:end_time]) + event_length)._dump
    else
      self.current_event = {:start_time => now._dump, :end_time => (now + event_length)._dump, :title => EVENT_TITLE}
    end
    self.save
  end
end
