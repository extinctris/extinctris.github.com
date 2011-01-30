require 'rake/clean'

CLEAN.include('dist').include('www/lib').include('www/deps')
CLOBBER.include('dist').include('www/lib').include('www/deps')

directory 'dist/ggj'
directory 'www/lib'
directory 'www/deps'

# Github gets mad at us for putting these in www/lib/ with everything else (they don't appear on extinctris.github.com).
# Not sure why, but easy to workaround.
desc 'build dependencies'
task :deps => ['www/deps'] do
  FileList['deps/*'].each do |f|
    sh "ln -sf ../../#{f} www/deps"
  end
end

task :build => [:deps,:assets] do
  sh 'coffee -o www/lib -c src test'
end

desc 'build dev sources continuously'
task :watch => [:deps,'www/lib'] do
  sh 'coffee -w -o www/lib -c src test'
end

task :mkDist => [:build, 'dist/ggj'] do
  sh 'rm -rf dist/ggj' #yes, ugly; sorry
  sh 'mkdir -p dist/ggj'
  # http://globalgamejam.org/wiki/hand-procedure
  # Submit the game in form of one (1!) compressed file format (zip preferred) with the following file and directory structure:
  #
  # /src/ => the full sourcecode with all assets of the project
  sh 'git clone . dist/ggj/src/'
  sh 'rm -rf dist/ggj/src/.git' #don't leak my local filesystem info into git-config please
  # /release/ the distributable files including a README.TXT with full installation instructions
  sh 'rsync -auvL --delete www/ dist/ggj/release/'
  # /press/ one hi-res image called press.jpg to be used for GGJ PR (1024x768 or better)
  sh 'mkdir dist/ggj/press'
  sh 'cp www/game.png dist/ggj/press/game.png' #But it's not 1024x768... well, whatever
  # /other/ additional media, photos, videos
  sh 'mkdir dist/ggj/other'
  # license.txt This is a small text file with precisely the content described here http://www.globalgamejam.org/content/license-and-distribution-agreement (just copy-paste the complete contents of the section License File Contents into license.txt)
  sh 'cp license.txt dist/ggj/license.txt'

  sh 'cp readme-ggj.txt dist/ggj/readme.txt'
  #
  # Upload the compressed file as an attachment on the game submission form. If your file is bigger than 500MBs or you are unable to upload for some reason, you have the option of uploading somewhere else and then providing a link in your game under "alternative download".
  sh 'cd dist/ggj/ && rm -f ../extinctris.zip && zip -r ../extinctris.zip .'
  sh 'ls -l dist/extinctris.zip'
end

desc 'deploy. This will destroy any uncommitted changes!'
task :deploy => [:mkDist,:todo] do
  # Github uses the master branch for extinctris.github.com, so we can't work there
  sh 'git co head'
  sh 'git branch -D master'
  sh 'git co -b master'
  begin
    sh 'rm -rf deps' #conflicting
    sh 'mv www/* .'
    sh 'git add .'
    sh 'git commit -am "[AUTO] github build"' 
    # This branch is just for publishing now. Losing history is okay, I promise
    sh 'git push -ff' 
  ensure
    sh 'git co head'
  end
end

# http://www.trottercashion.com/2010/10/29/replacing-make-with-rake.html
WAVS = FileList['assets/*.wav']
OGGS = WAVS.ext('.ogg')
#MP3S = WAVS.ext('.mp3')
task :sfx => OGGS
#task :sfx => MP3S
rule '.ogg' => '.wav' do |t|
  sh "oggenc #{t.source}"
end
#rule '.mp3' => '.wav' do |t|
#  sh "lame #{t.source} #{t.name}"
#end

desc 'run emacs for devel'
task :emacs do
  sh 'emacs todo `find www/ -type f -and \( -name "*.html" -o -name "*.css" \)` `find src test -type f` &'
end

desc 'graphics editing'
task :inkscape do
  sh 'inkscape assets/sprite.svg &'
end

task :assets => [:rasterize,:sfx]

# made with sfxr
task :sfx => ['www/lib'] do
  sh 'cp assets/*.ogg www/lib/'
  #sh 'cp assets/*.mp3 www/lib/'
end

task :rasterize => ['www/lib']
SPRITES = %w()
SPRITES.each do |id|
  png = "www/lib/#{id}.png"
  task :rasterize => png
  file png => 'assets/sprite.svg' do
    sh "inkscape assets/sprite.svg --export-png=#{png} --export-id=#{id} --export-id-only"
  end
end

# from http://ajaxload.info/
file 'www/lib/ajax-loader.gif' => ['assets/ajax-loader.gif'] do |t|
  sh "cp #{t.prerequisites} #{t.name}"
end
task :assets => [:sfx, :rasterize, 'www/lib/ajax-loader.gif']

desc 'line count of sources'
task :wc do
  sh 'wc -l `find src -type f`; wc -l `find test -type f`'
end

CHROMIUM='chromium-browser --allow-file-access-from-files --disable-web-security --user-data-dir=`mktemp -d /tmp/tmp.XXXXXXXXXXXX` --no-first-run'
desc 'launch it in chromium'
task :chromium do
  #sh 'chromium-browser --allow-file-access-from-files --user-data-dir=`mktemp -d /tmp/tmp.XXXXXXXXXXXX` --no-first-run --app file://`pwd`/www/index.html &'
  # allow-file-access-from-files: make img/css/script includes work locally (i think)
  # disable-web-security: ignore cors/same-origin-policy, to allow couchdb access from file:// without couchdb deployment
  sh "#{CHROMIUM} file://`pwd`/www/index.html file://`pwd`/www/test.html &"
end
FIREFOX='firefox'
desc 'launch it in firefox'
task :firefox do
  sh "#{FIREFOX} file://`pwd`/www/index.html file://`pwd`/www/test.html &"
end
desc 'launch it fullscreen'
task :fullchromium do
  sh "#{CHROMIUM} --app=file://`pwd`/www/index.html &"
end
