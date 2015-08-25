## Background info ##

As a long time iTunes user, I rated most of my music so that the songs I like can be found quickly or played more often. I still use iTunes at work, but I recently switched to Linux, so that means no iTunes for me.

As my library is rather large, I decided to write a script to import my ratings from iTunes into [Amarok](http://amarok.kde.org), my new music player of choice.

itunes2amarok currently imports ratings and play counts. It does not import your music into Amarok, it only applies ratings you have set in iTunes to your music library in Amarok.

## Installation howto ##

  1. Make sure all your music is already in the collection in Amarok.
  1. Download the file above
  1. Open Amarok and select Plugins from the menu.
  1. Choose Install new script
  1. Select the newly downloaded file – iTunesRatings.amarokscript.tar.gz
  1. Run the newly installed script (in the “General” category)
  1. Find and select your iTunes Library XML File – should be named “iTunes Music Library.xml”
  1. Depending on the size of your library, get a cup of your favorite beverage
  1. If your library is really big, why not go for lunch?


Known issues

  * Some people report problems with accented characters. If you encounter such problems, please send me a mail so I can fix it. If you can, send me a file where this happens. Central European characters work well and I don’t have many songs with other international characters.

  * The script needs kdialog to run correctly. If you installed Amarok without installing KDE, please also install kdebase.

In any case, should you encounter problems with the script, let me know.