extends RefCounted
# A true Gaussian blur for menu backdrops. The cover is shrunk to a small image, blurred
# with a separable Gaussian kernel on the CPU (once per cover, then cached) and drawn back
# up with linear filtering, which gives smooth, even colour fields without the rings or
# blotches a few-tap shader blur leaves, and costs the GPU nothing per frame.

static var _cache: Dictionary = {}

# side: working resolution (smaller = softer); sigma: blur strength in those pixels.
static func of(texture: Texture2D, side: int = 64, sigma: float = 6.0) -> Texture2D:
	if texture == null: return null
	var key = "%d:%d:%.2f" % [texture.get_instance_id(), side, sigma]
	if _cache.has(key):
		var cached: Texture2D = _cache[key]
		if cached: return cached
	var image: Image = texture.get_image()
	if image == null or image.is_empty(): return texture
	image = image.duplicate()
	if image.is_compressed(): image.decompress()
	image.convert(Image.FORMAT_RGBAF)
	var aspect = float(image.get_width()) / maxf(1.0, float(image.get_height()))
	var w = side if aspect >= 1.0 else maxi(4, roundi(side * aspect))
	var h = side if aspect <= 1.0 else maxi(4, roundi(side / aspect))
	image.resize(w, h, Image.INTERPOLATE_CUBIC)
	var kernel = _kernel(sigma)
	image = _pass(image, kernel, true)
	image = _pass(image, kernel, false)
	image.convert(Image.FORMAT_RGBA8)
	var result = ImageTexture.create_from_image(image)
	if _cache.size() > 48: _cache.clear()
	_cache[key] = result
	return result

static func _kernel(sigma: float) -> PackedFloat32Array:
	var radius = maxi(1, ceili(sigma * 3.0))
	var weights = PackedFloat32Array(); weights.resize(radius * 2 + 1)
	var total = 0.0
	for i in range(-radius, radius + 1):
		var v = exp(-float(i * i) / (2.0 * sigma * sigma)); weights[i + radius] = v; total += v
	for i in weights.size(): weights[i] /= total
	return weights

# One direction of the separable blur; edges are clamped so colour does not darken there.
static func _pass(source: Image, kernel: PackedFloat32Array, horizontal: bool) -> Image:
	var w = source.get_width(); var h = source.get_height()
	var out = Image.create(w, h, false, Image.FORMAT_RGBAF)
	var radius = (kernel.size() - 1) / 2
	for y in h:
		for x in w:
			var sum = Color(0, 0, 0, 0)
			for k in kernel.size():
				var o = k - radius
				var sx = clampi(x + o, 0, w - 1) if horizontal else x
				var sy = y if horizontal else clampi(y + o, 0, h - 1)
				sum += source.get_pixel(sx, sy) * kernel[k]
			out.set_pixel(x, y, sum)
	return out
