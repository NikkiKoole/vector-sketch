# requirement! install imagemagick 
# brew install imagemagick
# or build from source here http://www.imagemagick.org/script/binary-releases.php

#navigate to folder of the images
cd folderofmyimages/

# take every jpg in the folder and smash into a gif with a frame rate of 0.5 sec
convert -delay 50 *.jpg gif_of_my_images.gif 