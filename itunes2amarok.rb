#!/usr/bin/ruby



# itunes2amarok (for Amarok 1.4)
# ------------------------------
#
# You might want to backup your database
#
# How to proceed:
#
# 1. Export your iTunes library to an xml file
# 2. Run this script in Amarok
# 3. Restart Amarok -> et voila!
#
# (c) 2006 Pavol Murin
# Do whatever you want to this script, but please include my name in the derived works and copies
#
# Hints? Bugs? Please tell me - write me a mail: radostky.slovenskoo gmail com
#
#
# Thanks to Gaurav for finding a bug with missing DeviceId


# a simple class to hold all info about a specific track
class TrackInfo

  # comparable is necessary for testing, if there are no duplicates
  include Comparable

  attr :name         # track name
  attr :artist       # artist name
  attr :album        # album name
  attr :rating       # rating of the song (itunes exports it as an 0-100 (20=1star,40=2stars...)
  attr :play_date    # also sets the last play date
  attr :play_count   # and play count

  # a track is initialized directly from a iTunes exported xml file
  # the file read position is updated by reading
  def initialize(file)
    @name = ""
    @artist = ""
    @album = ""
    @rating = 0
    @play_date = 0
    @play_count = 0

    while line = file.gets
      break if line =~ /<\/dict>/
      key, value = $1, $2 if line =~ /<key>([^<]+)<\/key><[^>]*>([^<]*)<\/[^>]*>/

      @name       = value if key == "Name"
      @artist     = value if key == "Artist"
      @album      = value if key == "Album"
      @rating     = value.to_i if key == "Rating"
      @play_date  = value.to_i if key == "Play Date"
      @play_count = value.to_i if key == "Play Count"
    end

    p "Error: Track name not set" if name.nil?
  end

  def <=>(other)
    name <=> other.name
  end
end


# assumes the correct position in the file
def readTracks(filename)
  songs = Array.new

  skiplines = true
  trackdict = false

  p filename
  File.open(filename) do |file|
    while line = file.gets
      skiplines = skiplines && line !~ /<key>Tracks<\/key>/
      next if skiplines
      trackdict = trackdict || line =~ /<dict>/
      next unless trackdict

      break
    end

    skip = false

    while line = file.gets
      skip ||= line =~ /<\/dict>/
      next if skip

      songs.push(TrackInfo.new(file))
    end
  end

  songs
end


def safeForSql(sqlstring)
  sqlstring.gsub("'","''").gsub('"','\"').gsub("&#38;","&").gsub("&#62;",">").gsub("&#60;","<").strip
end

def dcopQuery(sqlquery)
  return `dcop amarok collection query \"#{sqlquery}\"`
end


# iterates all read songs with ratings
def applyToAmarok(songlist)
  index = 0

  songlist.each do |track|
    index += 1
    yield index

    next unless track.rating > 0

    # try to find the artist
    artist_id_str = dcopQuery("select id from artist where name = \'#{safeForSql(track.artist)}\'")
    artist_id = $1 if artist_id_str =~ /(\d+)/

    # try to find the album
    album_id_str = dcopQuery("select id from album where name = \'#{safeForSql(track.album)}\'")
    album_id = $1 if album_id_str =~ /(\d+)/

    yield "artist id not found:  \"#{track.artist}\" - skipping" if artist_id.nil?
    next if artist_id.nil?

    yield "album id not found:    \"#{track.album}\" - skipping" if album_id.nil?
    next if album_id.nil?

    # only find the song, if both album and artist are known - if this is a major limitation, it might be removed later
    url_str, deviceid = dcopQuery("select url, deviceid from tags where title = \'#{safeForSql(track.name)}\' and artist = #{artist_id} and album = #{album_id}").split("\n")
    url = $1 if url_str =~ /(.+)/
    
    if url.nil?
      count_tracks_with_name = dcopQuery("select url from tags where title = \'#{safeForSql(track.name)}\'").split("\n").size

      yield "Rating not applied: URL not found for \"#{track.name}\" \"#{track.artist}\" \"#{track.album}\", but \"#{count_tracks_with_name}\" URLs found for the track name."
      next
    end

    # if the song was already played, the statistics should be updated.
    # otherwise insert a new statistics entry
    result_str = ""
    found_str = dcopQuery("select playcounter from statistics where url=\'#{safeForSql(url)}\'")
    if found_str =~ /(.+)/
      result_str = dcopQuery("update statistics set rating=#{(track.rating/10)} where url=\'#{safeForSql(url)}\'")
    else
      result_str = dcopQuery("insert into statistics (url, deviceid, createdate, accessdate, percentage, rating, playcounter) values(\'#{safeForSql(url)}\',#{deviceid},#{track.play_date},#{track.play_date},#{track.rating},#{track.rating/10},#{track.play_count})")
    end

    result = $1 if result_str =~ /(.+)/
    yield result if !result.nil?
    
  end # of each

end # of function






#-----------------------------------------------------------------------#



# this code is copied from score2ratings.rb

if !system( "dcop amarok playlist popupMessage \"iTunes Import Ratings started.\" > /dev/null 2>&1" ) then #Info message, and running check combined
    print "ERROR: A suitable Amarok wasn't found running!\n"
    exit(1) #Exit with error
end

# end of copied code



# get the filename of the iTunes Library
filename = `kdialog --title "iTunes Ratings Import" --getopenfilename . "*.xml |iTunes XML Library Files"`.chomp()

exit if filename.empty?

# show a dialog to show the progress of importing:

dialog = ""
trap( "SIGTERM" ) { system("dcop #{dialog} close") } if dialog.length > 0

dialog = `kdialog --title "iTunes Ratings Import" --progressbar "Importing iTunes ratings" 100`.chomp()
dialog = dialog.gsub( /DCOPRef\((.*),(.*)\)/, '\1 \2')
`dcop #{dialog} showCancelButton true`

#system("dcop ${dialog} setProgress 1") if dialog.length > 0
`dcop #{dialog} setProgress 1`
`dcop #{dialog} setLabel "Parsing the xml file"`

songlist = readTracks(filename)

`dcop #{dialog} setProgress 50`
sleep 0.5

test = songlist

if !test.uniq!.nil?
  `dcop #{dialog} setLabel "Duplicates found and will be skipped."` unless test.uniq!.nil?
  sleep 1
end

if songlist.empty?
  `dcop #{dialog} setLabel "The library file contains no readable data."` if songlist.empty?
  `dcop #{dialog} setProgress 100`
  sleep 1
  `dcop #{dialog} close`

  system( "dcop amarok playlist popupMessage \"iTunes Import finshed: No tracks found in the selected file.\"" )
  exit(0)
end


`dcop #{dialog} setLabel "Applying ratings"` unless songlist.empty?

messageCount = songlist.length

lastProgress = 50
newProgress = 0

File.open("itunesratings.log", "w") do |file|
  applyToAmarok(songlist) do |message|
    message = message.to_s.strip
    if message =~ /[0-9]+/
      newProgress = 50 + (50 * message.to_i)/messageCount
      if newProgress != lastProgress
        `dcop #{dialog} setProgress #{newProgress}`
        lastProgress = newProgress
      end
      `dcop #{dialog} setLabel "Processing song #{message.to_i} of #{messageCount}"`
    else
      file.write message
      file.write "\n"
      `dcop amarok playlist popupMessage "#{message}"`
    end

    if `dcop #{dialog} wasCancelled` =~ /true/
        `dcop #{dialog} close`
      system( "dcop amarok playlist popupMessage \"iTunes Import was canceled. Note: Some ratings might have already been set.\"")
      exit(0)
    end
  end
end

`dcop #{dialog} setProgress 100`
`dcop #{dialog} setLabel "Finished."`

sleep 0.5

`dcop #{dialog} close`

system( "dcop amarok playlist popupMessage \"iTunes Import finshed. All your tracks should now have the same ratings as in iTunes before. You will have to reload your playlist (or restart Amarok).\"" )

`kdialog --textbox itunesratings.log`
exit(0)
