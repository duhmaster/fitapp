package level

// CumulativeXPThresholds matches mobile LevelService.cumulativeXpThresholds (level L starts at thresholds[L-1]).
var CumulativeXPThresholds = []int{0, 100, 250, 500, 900, 1500, 2400, 3600, 5200, 7500, 10000}

// FromTotalXP returns level (1-based).
func FromTotalXP(total int) int {
	if total < 0 {
		total = 0
	}
	for i := len(CumulativeXPThresholds) - 1; i >= 0; i-- {
		if total >= CumulativeXPThresholds[i] {
			return i + 1
		}
	}
	return 1
}

// Progress returns XP into current level segment and span (denominator for progress bar).
func Progress(totalXP int) (into int, span int) {
	lv := FromTotalXP(totalXP)
	idx := lv - 1
	if idx < 0 {
		idx = 0
	}
	start := CumulativeXPThresholds[idx]
	var end int
	if idx+1 < len(CumulativeXPThresholds) {
		end = CumulativeXPThresholds[idx+1]
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
