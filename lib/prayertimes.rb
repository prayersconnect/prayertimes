require "prayertimes/version"
require "date"
module Prayertimes
	class Calculate


		# Names of the times

		@@timeNames = {
			'imsak'    => 'Imsak',
			'fajr'     => 'Fajr',
			'sunrise'  => 'Sunrise',
			'dhuhr'    => 'Dhuhr',
			'asr'      => 'Asr',
			'sunset'   => 'Sunset',
			'maghrib'  => 'Maghrib',
			'isha'     => 'Isha',
			'midnight' => 'Midnight'
		}



		# Calculation Methods

		@@methods = {
			'MWL'=> {
				'name'=> 'Muslim World League',
				'params'=> { 'fajr'=> 18, 'isha'=> 17 } },
				'ISNA'=> {
					'name'=> 'Islamic Society of North America (ISNA)',
					'params'=> { 'fajr'=> 15, 'isha'=> 15 } },
					'Egypt'=> {
						'name'=> 'Egyptian General Authority of Survey',
						'params'=> { 'fajr'=> 19.5, 'isha'=> 17.5 } },
						'Makkah'=> {
							'name'=> 'Umm Al-Qura University, Makkah',
				'params'=> { 'fajr'=> 18.5, 'isha'=> '90 min' } },  # fajr was 19 degrees before 1430 hijri
				'Karachi'=> {
					'name'=> 'University of Islamic Sciences, Karachi',
					'params'=> { 'fajr'=> 18, 'isha'=> 18 } },
					'Tehran'=> {
						'name'=> 'Institute of Geophysics, University of Tehran',
				'params'=> { 'fajr'=> 17.7, 'isha'=> 14, 'maghrib'=> 4.5, 'midnight'=> 'Jafari' } },  # isha is not explicitly specified in this method
				'Jafari'=> {
					'name'=> 'Shia Ithna-Ashari, Leva Institute, Qum',
					'params'=> { 'fajr'=> 16, 'isha'=> 14, 'maghrib'=> 4, 'midnight'=> 'Jafari' } }
				}


		# Default Parameters in Calculation Methods

		@@defaultParams = {
			'maghrib'=> '0 min', 'midnight'=> 'Standard'
		}



		#---------------------- Default Settings --------------------


		@@calcMethod = 'MWL'


		# do not change anything here; use adjust method instead

		@@settings = {
			"imsak"    => '10 min',
			"dhuhr"    => '0 min',
			"asr"      => 'Standard',
			"highLats" => 'NightMiddle'
		}



		@@timeFormat = '24h'



		@@timeSuffixes = ['am', 'pm']



		@@invalidTime =  '-----'



		@@numIterations = 1



		@@offset = {}



		#---------------------- Initialization -----------------------
		
		def initialize(method = "MWL")
			@@methods.each do |method, config|
				@@defaultParams.each do |name, value|
					# if name in config['params'] || config['params'][name] != nil
					config['params'][name] = value
					# end
				end
			end

			@@calcMethod = method #if method in @@methods else 'MWL'

			params = @@methods[@@calcMethod]['params']
			params.each do |name, value|
				@@settings[name] = value
			end

			@@timeNames.each do |name, value|
				@@offset[name] = 0
			end

		end


		#-------------------- Interface Functions --------------------

		def setMethod(method)
			if @@methods[method]
				self.adjust(@@methods[method].params)
				self.calcMethod = method
			end
		end

		def adjust(params)
			@@settings.update(params)
		end

		def tune(timeOffsets)
			@@offset.update(timeOffsets)
		end

		def getMethod
			return @@calcMethod
		end

		def getSettings
			return @@settings
		end

		def getOffsets
			return @@offset
		end

		def getDefaults
			return @@methods
		end

		# return prayer times for a given date
		def getTimes(date, coords, timezone, dst = 0, format = nil)
			@lat = coords[0]
			@lng = coords[1]
			@elv =  coords.length >2 ? coords[2] : 0

			if format != nil
				@@timeFormat = format
			end

			if Date.parse(date)
				date = Date.parse(date)
				date = [date.year, date.month, date.day]
			end

			@timeZone = timezone + (dst ? 1 : 0)
			@jDate = self.julian(date[0], date[1], date[2]) - @lng / (15 * 24.0)
			return self.computeTimes
		end

		# convert float time to the given format (see timeFormats)
		def getFormattedTime(time, format, suffixes = nil)
			
			return self.invalidTime if time.nan?

			return time if format == 'Float'

			suffixes = @@timeSuffixes if suffixes == nil

			time = self.fixhour(time+ 0.5/ 60)  # add 0.5 minutes to round
			hours = time.floor

			minutes = ((time - hours)* 60).floor
			suffix = format == '12h' ? suffixes[ hours < 12 ? 0 : 1 ]  : ''
			if format == "24h"
				formattedTime = "#{hours}:#{minutes}"
			else
				formattedTime = "#{(hours+11)%12+1}:#{minutes}"
			end
			
			return formattedTime + suffix

		end

		#---------------------- Calculation Functions -----------------------

		# compute mid-day time
		def midDay(time)
			eqt = self.sunPosition(@jDate + time)[1]
			return self.fixhour(12 - eqt)
		end

		# compute the time at which sun reaches a specific angle below horizon
		def sunAngleTime(angle, time, direction = nil)
			angle
			time
			begin
				decl = self.sunPosition(@jDate + time)[0]
				noon = self.midDay(time)
				t = 1/15.0* self.arccos((-self.sin(angle)- self.sin(decl)* self.sin(@lat))/ (self.cos(decl)* self.cos(@lat)))
					
				return noon + (direction == 'ccw' ? -t  : t)
			rescue 
				return ('nan').to_f
			end
		end

		# compute asr time
		def asrTime(factor, time)
			decl = self.sunPosition(@jDate + time)[0]
			angle = -self.arccot(factor + self.tan((@lat - decl).abs))
			return self.sunAngleTime(angle, time)
		end

		# compute declination angle of sun and equation of time
		# Ref: http://aa.usno.navy.mil/faq/docs/SunApprox.php
		def sunPosition(jd)
			d = jd - 2451545.0
			g = self.fixangle(357.529 + 0.98560028* d)
			q = self.fixangle(280.459 + 0.98564736* d)
			l = self.fixangle(q + 1.915* self.sin(g) + 0.020* self.sin(2*g))

			r = 1.00014 - 0.01671*self.cos(g) - 0.00014*self.cos(2*g)
			e = 23.439 - 0.00000036* d

			ra = self.arctan2(self.cos(e)* self.sin(l), self.cos(l))/ 15.0
			eqt = q/15.0 - self.fixhour(ra)
			decl = self.arcsin(self.sin(e)* self.sin(l))

			return [decl, eqt]
		end

		# convert Gregorian date to Julian day
		# Ref: Astronomical Algorithms by Jean Meeus
		def julian(year, month, day)
			if month <= 2
				year -= 1
				month += 12
			end
			a = (year / 100).floor
			b = 2 - a + (a / 4).floor
			return (365.25 * (year + 4716)).floor + (30.6001 * (month + 1)).floor + day + b - 1524.5
		end

		#---------------------- Compute Prayer Times -----------------------

		# compute prayer times at given julian date
		def computePrayerTimes(times)
			times   = self.dayPortion(times)
			params  = @@settings

			imsak   = self.sunAngleTime(self.eval(params['imsak']), times['imsak'], 'ccw')
			fajr    = self.sunAngleTime(self.eval(params['fajr']), times['fajr'], 'ccw')
			sunrise = self.sunAngleTime(self.riseSetAngle(@elv), times['sunrise'], 'ccw')
			dhuhr   = self.midDay(times['dhuhr'])
			asr     = self.asrTime(self.asrFactor(params['asr']), times['asr'])
			sunset  = self.sunAngleTime(self.riseSetAngle(@elv), times['sunset'])
			maghrib = self.sunAngleTime(self.eval(params['maghrib']), times['maghrib'])
			isha    = self.sunAngleTime(self.eval(params['isha']), times['isha'])
			return {
				'imsak'=> imsak, 'fajr'=> fajr, 'sunrise'=> sunrise, 'dhuhr'=> dhuhr,
				'asr'=> asr, 'sunset'=> sunset, 'maghrib'=> maghrib, 'isha'=> isha
			}
		end

		# compute prayer times
		def computeTimes
			times = {
				'imsak'=> 5, 'fajr'=> 5, 'sunrise'=> 6, 'dhuhr'=> 12,
				'asr'=> 13, 'sunset'=> 18, 'maghrib'=> 18, 'isha'=> 18
			}
			# main iterations
			@@numIterations.times do
				times = self.computePrayerTimes(times)
			end
			times = self.adjustTimes(times)
			# add midnight time
			if @@settings['midnight'] == 'Jafari'
				times['midnight'] = times['sunset'] + self.timeDiff(times['sunset'], times['fajr']) / 2
			else
				times['midnight'] = times['sunset'] + self.timeDiff(times['sunset'], times['sunrise']) / 2
			end

			times = self.tuneTimes(times)
			return self.modifyFormats(times)
		end

		# adjust times in a prayer time array
		def adjustTimes(times)
			params = @@settings
			tzAdjust = @timeZone - @lng / 15.0
			times.each do |t,v|
				times[t] += tzAdjust
			end

			if params['highLats'] != nil
				times = self.adjustHighLats(times)
			end

			if self.isMin(params['imsak'])
				times['imsak'] = times['fajr'] - self.eval(params['imsak']) / 60.0
			end
			# need to ask about '@@settings
			if self.isMin(params['maghrib'])
				times['maghrib'] = times['sunset'] - self.eval(params['maghrib']) / 60.0
			end

			if self.isMin(params['isha'])
				times['isha'] = times['maghrib'] - self.eval(params['isha']) / 60.0
			end
			times['dhuhr'] += self.eval(params['dhuhr']) / 60.0

			return times
		end

		# get asr shadow factor
		def asrFactor(asrParam)
			methods = {'Standard'=> 1, 'Hanafi'=> 2}
			return methods[asrParam] ? methods[asrParam] : self.eval(asrParam)
		end

		# return sun angle for sunset/sunrise
		def riseSetAngle(elevation = 0)
			elevation =  elevation == nil ? 0 : elevation
			return 0.833 + 0.0347 * Math.sqrt(elevation) # an approximation
		end

		# apply offset to the times
		def tuneTimes(times)
			times.each do |name, value|
				@@offset
				times[name] += @@offset[name] / 60.0
			end
			return times
		end

		# convert times to given time format
		def modifyFormats(times)
			times.each do |name, value|
				times[name] = self.getFormattedTime(times[name], @@timeFormat)
			end
			return times
		end

		# adjust times for locations in higher latitudes
		def adjustHighLats(times)
			params = @@settings
			nightTime = self.timeDiff(times['sunset'], times['sunrise']) # sunset to sunrise
			times['imsak'] = self.adjustHLTime(times['imsak'], times['sunrise'], self.eval(params['imsak']), nightTime, 'ccw')
			times['fajr']  = self.adjustHLTime(times['fajr'], times['sunrise'], self.eval(params['fajr']), nightTime, 'ccw')
			times['isha']  = self.adjustHLTime(times['isha'], times['sunset'], self.eval(params['isha']), nightTime)
			times['maghrib'] = self.adjustHLTime(times['maghrib'], times['sunset'], self.eval(params['maghrib']), nightTime)
			return times
		end

		# adjust a time for higher latitudes
		def adjustHLTime(time, base, angle, night, direction = nil)
			portion = self.nightPortion(angle, night)
			diff =  direction == 'ccw' ? self.timeDiff(time, base) : self.timeDiff(base, time)
			if time.nan? or diff > portion
				time = base + ( direction == 'ccw' ? -portion : portion)
			end
			return time
		end

		# the night portion used for adjusting times in higher latitudes
		def nightPortion(angle, night)
			method = @@settings['highLats']
			portion = 1/2.0  # midnight
			if method == 'AngleBased'
				portion = 1/60.0 * angle
			end
			if method == 'OneSeventh'
				portion = 1/7.0
			end
			return portion * night
		end

		# convert hours to day portions
		def dayPortion(times)
			times.each do |key, value|
				times[key] = value /= 24.0
			end
			return times
		end


		#---------------------- Misc Functions -----------------------

		# compute the difference between two times
		def timeDiff(time1, time2)
			return self.fixhour(time2- time1)
		end

		# convert given string into a number
		def eval(st)
			val = st.to_s.split('[^0-9.+-]')[0]
			return   val ? val.to_f : 0
		end

		# detect if input contains 'min'
		def isMin(arg)
			return arg.to_s.include?('min')
		end


		#----------------- Degree-Based Math Functions -------------------

		def sin(d) return Math.sin((d) * Math::PI / 180); end
		def cos(d) return Math.cos((d) * Math::PI / 180); end
		def tan(d) return Math.tan((d) * Math::PI / 180); end

		def arcsin(x) return ((Math.asin(x)* 180.0) / Math::PI); end
		def arccos(x) return ((Math.acos(x)* 180.0) / Math::PI); end
		def arctan(x) return ((Math.atan(x)* 180.0) / Math::PI); end

		def arccot(x) return ((Math.atan(1.0/x)* 180.0) / Math::PI); end
		def arctan2(y, x) return ((Math.atan2(y, x)* 180.0) / Math::PI); end

		def fixangle(angle) return self.fix(angle, 360.0); end
		def fixhour(hour) return self.fix(hour, 24.0); end

		def fix(a, mode)
			if a.nan?
				return a
			end
			a = a - mode * ((a / mode).floor)
			return  a < 0 ? a + mode : a
		end

		# pt = Calculate.new
		# pt.getTimes(Time.now.asctime, [43, -79], -5)
	end
end
