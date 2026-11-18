# Custom label symbols

Put your own images here to use them on labels with `{image(name)}` (or
`"img:name"` in `make_label.py`). Files are looked up by name, with or without
the extension, case-insensitively. The icon set in
`../gridfinity-bin-label-icons-other_files/Icon Set PNG` is searched as well.

- **SVG** is used as-is and gives the cleanest result.
- **PNG / JPG** are traced: dark pixels become raised, white or transparent
  pixels are background. Use simple, high-contrast black-on-white artwork.
  Add a threshold (`{image(name, 100)}`) if the edges come out too thick or
  thin, or `invert` for light-on-dark artwork.

List everything available with:

    python image_fragment.py --list-images
