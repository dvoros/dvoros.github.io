---
title: "Personalized 3D Printed Gifts"
date: 2021-08-27T13:41:30+02:00
draft: false
tags:
- 3dprint
- inkscape
- blender
categories:
- notes
---

Even though most wedding invitations (at least the ones that I receive) tend to
kindly ask for presents that fit in an envelope, I like to stick out. Cash is
probably the best present in such occasions but you can surely be more creative
than an envelope with a few kind words!

In the past few years I've created a couple personalized cash-holders to serve
as wedding gifts. I've made some models from scratch and also printed some
stuff from [Thingiverse](https://www.thingiverse.com/). I've had the most
success with this
[Labyrinth Gift Box](https://www.thingiverse.com/thing:201097):

{{< container-image path="images/labyrinth-gift-box-by-sneakypoo.webp" width=80% >}}

It's a fun way to make the couple work for their money and from what I've heard
it's especially challenging on "hungover day" after a wedding. It's a lot more
fun though if the print is personalized with an embedded logo. Some couples
have a logo made for their wedding website, some just use their initials and for
some I just had to be creative and figure something out myself:

{{< container-image path="images/labyrinth-gift-cunda.jpg" width=70% >}}

It would be somewhat simpler to achieve this with a multi-colored printer but I
only have a good old Ender-3. This post describes how I'm creating snap-togeter
(and sometimes glued-together) **multi-colored 3D prints with a single-color
printer**. Another example use-case being
[this](https://www.thingiverse.com/thing:2975945)
set of boardgame pieces:

{{< container-image path="images/hive-pieces.jpg" width=70% >}}

{{< hint info >}}
Weddings are just rare enough for me to forget this technique. This writing mostly
serves as a **reminder for myself** for when I next need this. If you're reading this
(and you're not me) and need more detail on anything, let me know in the
comments!
{{< /hint >}}

## Vectorizing the image

So you have an image of a logo that you want to embed in a 3D print. Most of the
time it will be a
[raster graphic](https://en.wikipedia.org/wiki/Raster_graphics)
(e.g. PNG/JPG image). The first step before you can add the third dimension to
this 2D image is
[vectorizing](https://en.wikipedia.org/wiki/Image_tracing)
it. If you happen to have vector graphics available, you can skip this step.

If you search for
[image vectorization](https://www.google.com/search?q=image+vectorization) you
will find a number of online solutions. I'm sure at least some of these will
work well, but I'm not familiar with any of them. When it comes to vector
graphics, I'm using
[Inkscape](https://inkscape.org/).

The goal is to create two vectorized images from the original:

- one for the colored logo that you'll insert into the print, and
- one for the socket where you insert the logo. Due to the tolerances of your
3D printer, you can't create a socket of exactly the same size as the logo and
expect it to fit. The socket needs to be the "outset" of the logo with a few tenths
of a millimeter slack between them.

{{< container-image path="images/vectorization-process.png" width=70% >}}

### Preprocessing might be required

If your image isn't just a logo or if it isn't clean enough, you might need to
do some preprocessing in a raster graphics editor
(my choice being
[GIMP](https://www.gimp.org/))
before you can vectorize it.
The goal is to turn your image into a single-color logo with clean
edges/boundaries so that it's easy to trace.

This process varies greatly based on what you're starting from. If you're using
GIMP, `Colors -> Levels...` might help get you started but often times you'll
have to do some manual drawing over the logo to get it to work. Example:

{{< container-image path="images/vectorization-preprocessing.jpg" width=70% >}}

### Vectorization in Inkscape

This should be fairly simple:

- Fire up Inkscape and use `File -> Open...` to open your image
- Select the image by clicking on it
- `Path -> Trace Bitmap...` and click `Ok`
- The resulting path is created over your original image. Move it away by
dragging
- Delete the original image
- If you know exactly what size you need the logo in real life (as in
millimeters), it helps if you resize the path to that with `Object -> Transform... -> Scale`
- Resize page to content with: `File -> Document Properties... -> Resize page to content...`
- Save the vectorized result as SVG with: `File -> Save`

### The socket

You need to apply an "outset" on the logo to get to the socket. You can do it at

## 2D image to 3D model

