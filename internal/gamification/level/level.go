package level

// CumulativeXPThresholds matches mobile LevelService.cumulativeXpThresholds (level L starts at thresholds[L-1]).
var CumulativeXPThresholds = []int{0, 100, 250, 500, 900, 1500, 2400, 3600, 5200, 7500, 10000}

// NormalizeThresholds validates and normalizes custom thresholds.
// Falls back to defaults if invalid; guarantees first value is 0 and strict growth.
func NormalizeThresholds(in []int) []int {
	if len(in) < 2 {
		return CumulativeXPThresholds
	}
	out := make([]int, 0, len(in))
	for i, v := range in {
		if i == 0 {
			if v != 0 {
				return CumulativeXPThresholds
			}
			out = append(out, 0)
			continue
		}
		if v <= out[len(out)-1] {
			return CumulativeXPThresholds
		}
		out = append(out, v)
	}
	return out
}

// FromTotalXP returns level (1-based).
func FromTotalXP(total int) int {
	return FromTotalXPWithThresholds(total, CumulativeXPThresholds)
}

func FromTotalXPWithThresholds(total int, thresholds []int) int {
	thresholds = NormalizeThresholds(thresholds)
	if total < 0 {
		total = 0
	}
	for i := len(thresholds) - 1; i >= 0; i-- {
		if total >= thresholds[i] {
			return i + 1
		}
	}
	return 1
}

// Progress returns XP into current level segment and span (denominator for progress bar).
func Progress(totalXP int) (into int, span int) {
	return ProgressWithThresholds(totalXP, CumulativeXPThresholds)
}

func ProgressWithThresholds(totalXP int, thresholds []int) (into int, span int) {
	thresholds = NormalizeThresholds(thresholds)
	lv := FromTotalXPWithThresholds(totalXP, thresholds)
	idx := lv - 1
	if idx < 0 {
		idx = 0
	}
	start := thresholds[idx]
	var end int
	if idx+1 < len(thresholds) {
		end = thresholds[idx+1]
	} else {
		end = start + 5000
	}
	span = end - start
	if span < 1 {
		span = 1
	}
	into = totalXP - start
	if into < 0 {
		into = 0
	}
	if into > span {
		into = span
	}
	return into, span
}
