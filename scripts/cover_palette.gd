class_name SynkCoverPalette

# Turns cover art into the three gameplay colors (tap, sustained, flick) plus a dark stage tone.
# Hues are kept apart so note types stay readable even on single-color covers.
const DEFAULT = [Color("38baff"), Color("a36aff"), Color("ffd447")]
const HUE_BINS = 24
const MIN_SEPARATION = 50.0/360.0

static func hue_distance(a: float, b: float) -> float:
	var d = absf(a-b)
	return minf(d,1.0-d)

static func neon(hue: float, saturation: float) -> Color:
	# Bright, saturated enough to glow on the dark highway without washing out to white.
	return Color.from_hsv(fposmod(hue,1.0),clampf(saturation,.58,.85),1.0)

# Returns {"notes": [tap, sustained, flick], "stage": Color, "from_cover": bool}.
static func from_image(source: Image) -> Dictionary:
	if source == null or source.is_empty(): return fallback()
	var image = source.duplicate() as Image
	if image.is_compressed() and image.decompress() != OK: return fallback()
	image.convert(Image.FORMAT_RGBA8)
	image.resize(32,32,Image.INTERPOLATE_BILINEAR)
	var weights: Array = []; weights.resize(HUE_BINS); weights.fill(0.0)
	var hue_x: Array = []; hue_x.resize(HUE_BINS); hue_x.fill(0.0)
	var hue_y: Array = []; hue_y.resize(HUE_BINS); hue_y.fill(0.0)
	var saturation_sum: Array = []; saturation_sum.resize(HUE_BINS); saturation_sum.fill(0.0)
	var total = 0.0
	for y in image.get_height():
		for x in image.get_width():
			var c = image.get_pixel(x,y)
			if c.a < .5 or c.s < .2 or c.v < .18: continue
			# Vivid pixels define the mood far more than muddy ones.
			var w = c.s*c.s*c.v
			var bin = mini(int(c.h*HUE_BINS),HUE_BINS-1)
			weights[bin] += w; saturation_sum[bin] += c.s*w
			hue_x[bin] += cos(c.h*TAU)*w; hue_y[bin] += sin(c.h*TAU)*w
			total += w
	# A grayscale or nearly colorless cover keeps the house palette.
	if total < 6.0: return fallback()
	var ranked: Array = []
	for bin in HUE_BINS:
		# Neighboring bins share their weight so a hue split across a boundary still wins.
		var score = weights[bin] + .5*(weights[(bin+1)%HUE_BINS] + weights[(bin+HUE_BINS-1)%HUE_BINS])
		if weights[bin] <= 0: continue
		ranked.append({"hue":fposmod(atan2(hue_y[bin],hue_x[bin])/TAU,1.0),"score":score,"saturation":saturation_sum[bin]/weights[bin],"weight":weights[bin]})
	ranked.sort_custom(func(a,b): return a.score > b.score)
	var picked: Array = [ranked[0]]
	for candidate in ranked:
		if picked.size() >= 3: break
		if candidate.weight < total*.04: continue
		var apart = true
		for chosen in picked:
			if hue_distance(candidate.hue,chosen.hue) < MIN_SEPARATION: apart = false
		if apart: picked.append(candidate)
	var hues: Array = []
	for chosen in picked: hues.append(chosen.hue)
	# Fill missing roles with hues that stay clearly distinct from what the cover gave us.
	if hues.size() < 2: hues.append(fposmod(hues[0]+.16,1.0))
	if hues.size() < 3:
		var best = 0.0; var best_distance = -1.0
		for step in 36:
			var hue = step/36.0
			var distance = minf(hue_distance(hue,hues[0]),hue_distance(hue,hues[1]))
			if distance > best_distance: best_distance = distance; best = hue
		hues.append(best)
	var saturation = picked[0].saturation
	var colors = [neon(hues[0],saturation),neon(hues[1],saturation),neon(hues[2],saturation+.1)]
	var stage = Color.from_hsv(hues[0],clampf(saturation,.5,.8),.17)
	return {"notes":colors,"stage":stage,"from_cover":true}

static func fallback() -> Dictionary:
	return {"notes":DEFAULT.duplicate(),"stage":Color("0b1030"),"from_cover":false}
