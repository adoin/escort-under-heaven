extends RefCounted

const TITLES = {"jinyiwei":"锦衣卫指挥使", "dongchang":"东厂掌权人", "alliance":"武林盟主", "wealth":"明朝首富"}


static func phase(progress: Dictionary) -> String:
	var influence := maxi(progress.credit, maxi(progress.renown, progress.guild))
	if influence >= 70 and not progress.milestones.is_empty():
		return "左右局势"
	if (progress.trips >= 8 and influence >= 45) or progress.milestones.has("regional"):
		return "名动一方"
	if progress.trips >= 3 or progress.milestones.has("mediation"):
		return "崭露头角"
	return "初入江湖"


static func requirements(route: String, progress: Dictionary, assets: int) -> String:
	var missing: PackedStringArray = []
	match route:
		"jinyiwei", "dongchang":
			if progress.credit < 85: missing.append("官面信用 85")
			if progress.cases.size() < 3: missing.append("核验 3 宗要案")
			if not progress.nominations.has(route): missing.append("所选机构举荐")
			if not progress.milestones.has(route): missing.append("任命事件")
		"wealth":
			if assets < 1000000: missing.append("净资产 100 万两")
			if progress.guild < 80: missing.append("商帮信用 80")
			if progress.routes.size() < 3: missing.append("3 条已结算商路")
			if not progress.milestones.has("top_wealth"): missing.append("商会核验排名登顶")
		"alliance":
			if progress.renown < 85: missing.append("武林声望 85")
			if progress.sponsors.size() < 4: missing.append("4 个独立门派支持")
			if not progress.milestones.has("assembly"): missing.append("大会擂试与公议")
		_:
			return "未知路线"
	if route != "wealth" and progress.office != "" and progress.office != route:
		missing.append("先辞去%s" % TITLES[progress.office])
	return "、".join(missing)
