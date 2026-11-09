The reasoning behind `tkg/scripts/ui/ChromeSlide.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Chrome slide

Above `static var live: Array = []`:

```text
THE CHROME SLIDES OFF LOCAL AND BACK (Jon, Oct 13: "when you move from
sector to local or starchart to local... the tooltip bar moves up and the
side bar slides to the right as the local image expands. the opposite
happens when you move from local to sector or local to starchart").

A piece of a screen's chrome as one solid thing: the toolbar's band, or the
side bar's column (the gap beside the picture's frame and the panel), at
`rest` where it stands and `off` away from there when it is gone -- up for
the band, right for the column. Into LOCAL it is the picture of the chrome
being left (`tex`, the held frame), sliding off as LOCAL's camera lands;
out of LOCAL it is the arriving screen's chrome, empty -- its ground and its
panel's plate (`plate`) -- sliding on as LOCAL's camera leaves, its contents
decoding in once it has landed (`SideSwap`). LOCAL is never scaled: it is
drawn whole underneath and the chrome uncovers or covers it, so its pixels
stay its own.

Moved in whole pixels and never drawn outside the screens' area (`clip`).
Takes the clicks on it until it has gone (`_has_point`): what is under it
is about to be, or has just stopped being, somewhere else.
```
