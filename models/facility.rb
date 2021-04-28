require 'proxy_object'

class Facility < ProxyObject
  
  def opened? time=Time.now
    return false if day_off? time.to_date
    @opened_hours ||= begin
      case business_hours
      when /^(\d{1,2}):(\d{1,2})\-(\d{1,2}):(\d{1,2})/
        a = [$1, $2, $3, $4].map(&:to_i)
      else
        puts "unsupported business_hours #{business_hours}"
      end
    end
    y = time.year; m = time.month; d = time.day
    f = Time.new y, m, d, @opened_hours[0], @opened_hours[1]
    t = Time.new y, m, d, @opened_hours[2], @opened_hours[3]
    (f..t).include? time
  end

  def reservable_time? time=Time.now
    return false if day_off? time.to_date
    @reservation_hours ||= begin
      case reservation_hours || business_hours
      when /^(\d{1,2}):(\d{1,2})\-(\d{1,2}):(\d{1,2})/
        a = [$1, $2, $3, $4].map(&:to_i)
      else
        puts "unsupported business_hours #{reservation_hours || business_hours}"
      end
    end
    y = time.year; m = time.month; d = time.day
    f = Time.new y, m, d, @reservation_hours[0], @reservation_hours[1]

    # @reservable_periodを先に確定させる為の呼び出し
    reservable? unless @reservable_period
    # 正の値の場合は直接日付を指定している
    if @reservable_period[0] > 0
      return false unless (@reservable_period[0]..@reservable_period[1]).include?(time.day)
    end

    t = Time.new y, m, d, @reservation_hours[2], @reservation_hours[3]
    (f..t).include? time
  end

  def day_off? day=Date.new
    @off_days ||= begin
      (closed || "").split(",").map do |e|
        case e
        when /^(\d{1,2})\/(\d{1,2})\-(\d{1,2})\/(\d{1,2})$/
          a = [$1, $2, $3, $4].map(&:to_i)
          a[2] += 12 if a[0] > a[2]
          a
        when /^(\d{1,2})\/(\d{1,2})$/
          [$1, $2].map(&:to_i)
        else
          e 
        end
      end
    end
    m = day.month; d = day.day; w = day.wday
    @off_days.each do |a|
      case a
      when Array
        case a.size
        when 4
          r = a[0]..a[2]
          if r.include?(m) || r.include?(m + 12)
            if a[0] == m
              return true if a[1] <= d
            elsif a[2] == m || a[2] == m + 12
              return true if a[3] >= d
            else
              return true
            end
          end
        when 2
          return true if a == [m, d]
        end
      when 'sun'
        return true if w == 0
      when 'mon'
        return true if w == 1
      when 'tue'
        return true if w == 2
      when 'wed'
        return true if w == 3
      when 'thu'
        return true if w == 4
      when 'fri'
        return true if w == 5
      when 'sat'
        return true if w == 6
      end
    end
    false
  end

  def reservable? day=Date.today
    return false if day_off? day

    @reservable_period ||= begin
      a = self.deadline.split(" - ").to_a
      a = a.map{|d| /(.*)[th|day][s]?/ =~ d; $1.to_i}.sort
    end
    
    today = Date.today
    return false if day < today

    case @reservable_period.size
    when 1
      today < (day + @reservable_period[0])
    when 2
      if @reservable_period[0] > 0
        # 前月の指定期間のみ可能
        ((day.year * 12 + day.month - 1) - (today.year * 12 + today.month - 1) == 1) &&
          (@reservable_period[0]..@reservable_period[1]).include?(today.day)
      else
        # 利用日から指定期間前に可能
        ((day + @reservable_period[0])..(day + @reservable_period[1])).include?(today)
      end
    end
  end

  def readable_closed_days
    s = closed || ""
    %w(sun mon tue wed thu fri sat).zip(%w(日 月 火 水 木 金 土)).each do|pair|
      s = s.gsub(pair.first, pair.last)
    end
    s
  end

end
