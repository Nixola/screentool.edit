# screentool.edit
A very simple image editor. It probably doesn't make sense to anyone but me, but here it is nonetheless.

## Usage
Run it with LÖVE [https://love2d.org], pipe a PNG file in stdin and redirect stdout to where you want to save the resulting file.

## Features
* Draw lines by simply holding the left mouse button. Lines are automatically smoothed.
  * Hold `shift` before starting a line and it'll be straight instead.
  * Hold `ctrl` while drawing a straight line and it'll snap to 22.5°.
* Scroll your mouse wheel to change the size of the line you're drawing.
* Hold the right mouse button to activate the color wheel, release to choose a color.
* Hold the mouse wheel to highlight and pick a color from the image.
* Press `return` and type anything to add some text! Mouse wheel changes font size, `return` again adds the text wherever the pointer is.
* Press `c` to enter cropping mode:
  * Click and drag to select a rectangle to crop
  * Arrows move the rectangle around, alt+arrows resize it; shift accelerates both operations
  * `return` finalizes the crop and resizes the image.
* `Escape` cancels any ongoing operation (drawing a line, cropping, picking a color either way, writing text).
* `Ctrl+Z` undoes the last operation. The buffer is unending.
* `Ctrl+Y` redoes the last undone operation. The buffer is still unending. Note that doing *anything* after undoing *will* prevent you from redoing.
  * Honestly looking for feedback on that; it'd be trivial not to, but it feels counterintuitive.
* Holding `space` displays some additional information:
  * While drawing a line or not doing anything, it'll draw a horizontal and a vertical line spanning the screen centered on the mouse pointer for alignment purposes.
  * While cropping, it will show the new viewport size and current margins.
* I probably forgot something.

## Screenshots
There is literally no UI to speak of. I don't think a screenshot would mean anything.

## Todo
* Drawing rectangles
* Making a better color picker
* Open an issue if you, somehow, end up using this and would like to see a feature. Or even if you just end up using it.