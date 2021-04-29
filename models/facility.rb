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
      today <= end_on_for(day)
    when 2
      (start_on_for(day)..end_on_for(day)).include?(today)
    end
  end

  def readable_closed_days
    s = closed || ""
    %w(sun mon tue wed thu fri sat).zip(%w(日 月 火 水 木 金 土)).each do|pair|
      s = s.gsub(pair.first, pair.last)
    end
    s
  end

  def description_for day=Date.today
    return "休日のため利用できません。" if day_off?(day)
    return "予約問い合わせ可能です。" if reservable?(day)
      
    sd = start_on_for(day)
    ed = end_on_for(day)
    if ed < Date.today
      "受付は終了しました。"
    else
      if sd
        "#{sd.month}月#{sd.day}日から#{ed.month}月#{ed.day}まで受付ます。"
      else
        "#{ed.month}月#{ed.day}日で受付終了します。"
      end
    end
  end

  private

  def start_on_for day
    raise "@reservable_period is nil" if @reservable_period.nil?

    case @reservable_period.size
    when 1
      nil
    when 2
      if @reservable_period[0] > 0
        # 前月の指定期間のみ可能
        case day.month
        when 1
          return Date.new(day.year - 1, 12, @reservable_period[0])
        else
          return Date.new(day.year, day.month - 1, @reservable_period[0])
        end
      else
        return day + @reservable_period[0]
      end
    end
    nil
  end

  def end_on_for day
    raise "@reservable_period is nil" if @reservable_period.nil?

    case @reservable_period.size
    when 1
      return day + @reservable_period[0]
    when 2
      if @reservable_period[0] > 0
        # 前月の指定期間のみ可能
        case day.month
        when 1
          return Date.new(day.year - 1, 12, @reservable_period[1])
        else
          return Date.new(day.year, day.month - 1, @reservable_period[1])
        end
      else
        return day + @reservable_period[1]
      end
    end
    nil
  end

end
