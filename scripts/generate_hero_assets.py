"""Batch Tripo text_to_model generation of per-chapter hero and environment assets.

Usage:  python scripts/generate_hero_assets.py submit [ID ...]   # submit (all pending if no IDs)
        python scripts/generate_hero_assets.py poll                # poll + download finished
        python scripts/generate_hero_assets.py status
Records: assets/production/hero_jobs.json (no keys stored; only key slot numbers).
Key policy: slots 4-6 first, reserve 7-9 only when 4-6 cannot cover a job.
"""
import json
import os
import sys
import time
import urllib.error
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tripo_client as api  # noqa: E402

api.rotate_key = lambda: False  # choose slots explicitly
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RECORDS = os.path.join(ROOT, "assets", "production", "hero_jobs.json")
PRIMARY, RESERVE = [4, 5, 6], [7, 8, 9]
COST = 40  # measured P1 textured text_to_model cost; actual consumed_credit is recorded per task

STYLE = ("Photorealistic grounded AAA archaeological adventure game asset, earth-toned PBR materials, "
         "isolated single object, no base platform, no ground plane, no text, no logos, no people. ")
VAELOR = ("Ancient Vaelor civilization style: dark resonant obsidian-like basalt stone with concentric acoustic "
          "ring carvings and wave glyphs, weathered oxidized bronze fittings, moss and mineral staining. ")

# id: (chapter, out path relative to assets/, faces, prompt, collision hint)
ASSETS = {
    # Chapter 1 - arrival, mist valley base camp, First Sealed Portal
    "CH1_SEALED_PORTAL": ("Chapter1", "models/hero/ch1/ch1_first_sealed_portal.glb", 60000, VAELOR + "Massive sealed circular stone portal door set in a carved rock frame, concentric rings and a central resonance glyph, overgrown with jungle roots, 6 meters tall.", "trimesh(LOD3) frame + box door"),
    "CH1_EXPEDITION_CAMP_HUB": ("Chapter1", "models/hero/ch1/ch1_expedition_command_tent.glb", 40000, "Large modern archaeology expedition command tent, canvas with open front, folding tables with maps, survey tripod, lanterns, cables, field cases beside it, jungle camp.", "box"),
    "CH1_SUPPLY_TRUCK": ("Chapter1", "models/hero/ch1/ch1_expedition_supply_truck.glb", 40000, "Muddy old expedition 4x4 utility truck with roof rack, jerrycans and tarp-covered cargo, parked, jungle mud on tires.", "convex"),
    # Chapter 2 - First Ruin, hydraulic counterweight, Voice Below tablets
    "CH2_COUNTERWEIGHT": ("Chapter2", "models/hero/ch2/ch2_hydraulic_counterweight_machine.glb", 60000, VAELOR + "Ancient hydraulic counterweight machine: huge carved stone counterweight block hanging from bronze chains over a pulley frame, water channels and bronze pistons, 5 meters tall.", "convex parts; animate weight node"),
    "CH2_INSCRIBED_GATE": ("Chapter2", "models/hero/ch2/ch2_inscribed_vaelor_gate.glb", 60000, VAELOR + "Monumental inscribed stone gate with two heavy sliding stone doors covered in dense glyph inscriptions and bronze inlays, flanked by carved pillars, 5 meters tall.", "box per door + trimesh(LOD3) frame"),
    "CH2_VOICE_TABLETS": ("Chapter2", "models/hero/ch2/ch2_voice_below_tablet_wall.glb", 40000, VAELOR + "Wall of three large upright inscribed stone tablets on a carved plinth, deep glyph text, cracked edges, faint mineral glow in grooves.", "box"),
    "CH2_WATER_CISTERN": ("Chapter2", "models/hero/ch2/ch2_hydraulic_cistern_valve.glb", 40000, VAELOR + "Ancient stone water cistern basin with a large bronze valve wheel and outlet spout, channels carved into rim.", "convex; valve wheel separate interact"),
    # Chapter 3 - bridge breach
    "CH3_BRIDGE_SECTION": ("Chapter3", "models/hero/ch3/ch3_massive_bridge_section.glb", 60000, VAELOR + "Massive ancient stone arch bridge section spanning a chasm, thick deck with carved balustrades, cracked and partially broken at one end, 20 meters long.", "trimesh(LOD2) for walkable deck"),
    "CH3_PYLON_BROKEN_A": ("Chapter3", "models/hero/ch3/ch3_broken_pylon_a.glb", 40000, VAELOR + "Single tall square stone column whose top third is violently snapped off leaving a jagged diagonal fracture and dangling rubble, cracks running down the shaft. Tall broken bridge support pylon, carved stone column snapped at the top with jagged fracture, exposed bronze reinforcement rods, 12 meters tall.", "convex"),
    "CH3_PYLON_BROKEN_B": ("Chapter3", "models/hero/ch3/ch3_broken_pylon_b.glb", 40000, VAELOR + "Leaning collapsed bridge pylon base with large fallen chunks still attached, cracked carved stone, hanging chains, 8 meters tall.", "convex"),
    "CH3_BRIDGE_DEBRIS": ("Chapter3", "models/hero/ch3/ch3_fallen_bridge_deck_chunk.glb", 40000, VAELOR + "Large fallen bridge deck slab chunk tilted at an angle, broken balustrade fragments, cracked carved stone, usable as climbable ramp.", "convex"),
    # Chapter 4 - alone in caves, 19th-century expedition relics + Meridian camp (per director)
    "CH4_MERIDIAN_GENERATOR": ("Chapter4", "models/hero/ch4/ch4_meridian_generator.glb", 40000, "Rugged military diesel generator on skid frame, olive drab with black hazard panels, fuel lines, exhaust pipe, cable reels, abandoned.", "box"),
    "CH4_MERIDIAN_CRATE_STACK": ("Chapter4", "models/hero/ch4/ch4_meridian_crate_stack.glb", 40000, "Single combined stack of assorted private military supply crates and hard cases strapped together on a pallet with cargo net, dark grey and olive, stencil markings without text.", "box"),
    "CH4_MERIDIAN_TENT": ("Chapter4", "models/hero/ch4/ch4_meridian_field_tent.glb", 40000, "Abandoned private military contractor field tent, dark grey ripstop canvas, half collapsed, cot and equipment visible, guy ropes.", "box"),
    "CH4_LIGHT_TOWER": ("Chapter4", "models/hero/ch4/ch4_mobile_light_tower.glb", 40000, "Vertical straight telescopic mast pointing straight up from a small two-wheel trailer, rectangular bank of four flat LED floodlight panels at the top, diesel box on trailer, no crane arm, no boom. Mobile construction light tower on wheeled trailer, telescopic mast with four floodlight panels, olive military paint, cables.", "box base + capsule mast"),
    "CH4_1890_EXPEDITION_CACHE": ("Chapter4", "models/hero/ch4/ch4_1890s_expedition_relics.glb", 40000, "Abandoned 19th-century expedition camp remains in a cave: rotted wooden steamer trunks, brass theodolite, oil lantern, tattered canvas, rope ladder, skeleton-free.", "box"),
    # Chapter 5 - intruders
    "CH5_MERIDIAN_DRILL_RIG": ("Chapter5", "models/hero/ch5/ch5_meridian_excavation_drill.glb", 50000, "Industrial excavation drill rig on tracked base used by mercenaries to bore into ancient ruins, hydraulic arms, floodlights, dark grey military paint.", "convex"),
    "CH5_BARRICADE": ("Chapter5", "models/hero/ch5/ch5_meridian_cover_barricade.glb", 30000, "Mercenary defensive barricade made of hesco bastion bags and steel plates, chest high, 4 meters long, usable as cover.", "box"),
    "CH5_COMMS_MAST": ("Chapter5", "models/hero/ch5/ch5_meridian_comms_mast.glb", 30000, "Portable military satellite communications mast with dish antenna and equipment cases at base, cables, tripod legs.", "box base"),
    # Chapter 6 - drowned temple
    "CH6_TEMPLE_STATUE": ("Chapter6", "models/hero/ch6/ch6_drowned_temple_statue.glb", 60000, VAELOR + "Colossal seated guardian statue of a robed Vaelor priest holding a resonance disc, eroded by water, algae and calcite drips, 8 meters tall.", "convex"),
    "CH6_SLUICE_GATE": ("Chapter6", "models/hero/ch6/ch6_sluice_gate.glb", 50000, VAELOR + "Ancient sluice gate: heavy stone gate slab in carved channel frame with bronze gear rack and crank mechanism, water stains, 4 meters wide.", "box gate + trimesh(LOD3) frame"),
    "CH6_HYDRAULIC_WHEEL": ("Chapter6", "models/hero/ch6/ch6_great_hydraulic_wheel.glb", 60000, VAELOR + "Huge open-spoked waterwheel with many flat stone-and-bronze paddle buckets around its rim, visible radial spokes, standing upright between two carved stone axle pillars. Giant ancient water wheel of bronze and stone with paddles and carved hub, mounted on axle supports, 9 meters diameter.", "convex hub; rotate node"),
    "CH6_SUNKEN_AQUEDUCT": ("Chapter6", "models/hero/ch6/ch6_sunken_aqueduct_arches.glb", 50000, VAELOR + "Row of three partially collapsed aqueduct arches with water channel on top, carved stone, algae, 10 meters long.", "trimesh(LOD3)"),
    # Chapter 7 - lost city
    "CH7_LANDMARK_TOWER": ("Chapter7", "models/hero/ch7/ch7_city_of_echoes_tower.glb", 60000, VAELOR + "Very tall slender ancient stone tower, height five times its width, square tapering shaft with stacked tiers, carved resonance ring bands at each tier, pointed crown, small square windows. Cyclopean landmark tower of the underground City of Echoes, tall tapering stepped spire with resonance rings and balconies, 30 meters tall.", "convex"),
    "CH7_ARCHIVE_FACADE": ("Chapter7", "models/hero/ch7/ch7_archive_facade.glb", 60000, VAELOR + "Grand archive building facade carved into cliff, colonnade of thick pillars, massive doorway, rows of tablet niches, stairs, 15 meters wide.", "trimesh(LOD3)"),
    "CH7_TERRACED_RUINS": ("Chapter7", "models/hero/ch7/ch7_terraced_ruins.glb", 60000, VAELOR + "Stepped terraced ruin block with three levels of walls, stairways and broken dwellings, overgrown with cave moss, 12 meters wide.", "trimesh(LOD2) walkable"),
    "CH7_WATERFALL_CLIFF": ("Chapter7", "models/hero/ch7/ch7_waterfall_cliff.glb", 60000, "Tall wet limestone cliff face with carved channel notch where a waterfall would pour, layered rock, mossy ledges, 15 meters tall, no water mesh.", "trimesh(LOD3)"),
    "CH7_TOMB_SARCOPHAGUS": ("Chapter7", "models/hero/ch7/ch7_optional_tomb_sarcophagus.glb", 40000, VAELOR + "Ornate Vaelor stone sarcophagus with carved lid depicting a priest, resonance rings, bronze corner caps, on a plinth.", "box"),
    # Chapter 8 - betrayal, harmonic key
    "CH8_HARMONIC_KEY_ALTAR": ("Chapter8", "models/hero/ch8/ch8_harmonic_key_altar.glb", 50000, VAELOR + "Ceremonial altar pedestal with an empty cradle for the Harmonic Key, three curved stone arms, bronze tuning fork shapes, steps.", "convex"),
    "CH8_ELIAS_SYNDICATE_CAMP": ("Chapter8", "models/hero/ch8/ch8_syndicate_field_lab.glb", 40000, "Hidden mercenary field laboratory table cluster with sonar equipment, laptops closed, crates of artifacts, folding lamp, cables.", "box"),
    "CH8_COLLAPSED_STAIR": ("Chapter8", "models/hero/ch8/ch8_grand_collapsed_stairway.glb", 50000, VAELOR + "Grand ancient stairway climbing between two carved walls, partially collapsed in the middle, 10 meters long.", "trimesh(LOD2) walkable"),
    # Chapter 9 - heart road
    "CH9_SHEARED_CONDUIT": ("Chapter9", "models/hero/ch9/ch9_sheared_resonance_conduit.glb", 50000, VAELOR + "Huge broken resonance conduit pipe of carved stone and bronze rings, sheared in two by tectonic fault, 12 meters long.", "convex"),
    "CH9_FAULT_ROCK_SPLIT": ("Chapter9", "models/hero/ch9/ch9_tectonic_fault_rock.glb", 50000, "Massive split rock formation along a fresh tectonic fault, two jagged slabs with a gap, dust, cracked basalt, 10 meters tall.", "trimesh(LOD3)"),
    "CH9_HEART_ROAD_GATEHOUSE": ("Chapter9", "models/hero/ch9/ch9_heart_road_gatehouse.glb", 60000, VAELOR + "Ancient gatehouse arch over a processional road, flanked by twin carved guardian columns, cracked by earthquakes, 12 meters tall.", "trimesh(LOD3)"),
    # Chapter 10 - Heart Vault
    "CH10_HEART_CORE": ("Chapter10", "models/hero/ch10/ch10_heart_vault_core.glb", 60000, VAELOR + "Colossal resonant geode core centerpiece: giant sphere of dark crystal and obsidian encased in rotating bronze concentric rings on a stepped dais, crystal shards growing around it, 10 meters tall.", "sphere + convex dais"),
    "CH10_HARMONIC_PILLAR": ("Chapter10", "models/hero/ch10/ch10_harmonic_node_pillar.glb", 50000, VAELOR + "Harmonic node pillar: tall carved obsidian column with embedded crystal resonator at the top, bronze tuning fins, glowing glyph grooves, 6 meters tall.", "capsule/convex"),
    "CH10_GEODE_WALL": ("Chapter10", "models/hero/ch10/ch10_geode_crystal_wall.glb", 50000, "Curved section of a giant geode chamber wall with dense dark amethyst and quartz crystal clusters, 8 meters wide.", "trimesh(LOD3)"),
    # Finale / Epilogue
    "FIN_COLLAPSED_EXIT": ("Finale", "models/hero/finale/fin_collapsed_cave_exit.glb", 60000, "Collapsed cave exit tunnel mouth with huge fallen boulders and broken ancient carved lintel, narrow gap with daylight side, 8 meters tall.", "trimesh(LOD3)"),
    "FIN_RUBBLE_SLOPE": ("Finale", "models/hero/finale/fin_rockfall_rubble_slope.glb", 40000, "Large rockfall rubble slope of broken limestone slabs and carved stone fragments, climbable incline, 8 meters long.", "trimesh(LOD3) walkable"),
    "EPI_RIDGE_OVERLOOK": ("Epilogue", "models/hero/epilogue/epi_mist_ridge_rock_outcrop.glb", 50000, "Jungle mountain ridge rock outcrop overlook with moss, roots and small shrubs, sunlit limestone, 10 meters wide.", "trimesh(LOD3)"),
    # Prologue
    "PRO_RESONANT_GLYPH": ("Prologue", "models/hero/prologue/pro_resonant_glyph_monolith.glb", 50000, VAELOR + "Fallen carved monolith slab with a single large resonant glyph emblem, half buried in cave rubble, cracked, 3 meters long.", "convex"),
    # Jungle variety
    "JUN_TREE_A": ("Shared jungle", "models/jungle/jun_kapok_tree_buttress.glb", 50000, "Giant tropical kapok rainforest tree with huge buttress roots and tall straight trunk, leafy canopy, vines, 18 meters tall.", "capsule trunk"),
    "JUN_TREE_B": ("Shared jungle", "models/jungle/jun_strangler_fig_tree.glb", 50000, "Tropical strangler fig tree with twisted lattice of aerial roots wrapped around trunk, dense canopy, 14 meters tall.", "capsule trunk"),
    "JUN_TREE_C": ("Shared jungle", "models/jungle/jun_leaning_palm_cluster.glb", 40000, "Cluster of three leaning tropical palm trees of different heights, curved trunks, 10 meters tall.", "capsule per trunk"),
    "JUN_TREE_D": ("Shared jungle", "models/jungle/jun_mossy_dead_tree.glb", 40000, "Old broken jungle tree trunk, dead and moss covered with epiphytes and hanging vines, snapped top, 7 meters tall.", "capsule"),
    "JUN_ROOTS_A": ("Shared jungle", "models/jungle/jun_giant_surface_roots_a.glb", 40000, "Sprawling giant tree surface roots spreading over the ground, mossy, twisting, 6 meters wide, no trunk.", "convex/trimesh(LOD3)"),
    "JUN_ROOTS_B": ("Shared jungle", "models/jungle/jun_root_arch_over_stone.glb", 40000, "Thick jungle roots arching over and gripping a broken carved stone block, mossy, 4 meters wide.", "convex"),
    "JUN_ROOTS_C": ("Shared jungle", "models/jungle/jun_hanging_root_curtain.glb", 30000, "Curtain of hanging aerial roots and vines from a rock overhang, 5 meters tall.", "none (visual)"),
    "JUN_FERN_A": ("Shared jungle", "models/jungle/jun_fern_cluster_tree_fern.glb", 30000, "Cluster of large tropical tree ferns and broad leaf understory plants, 3 meters tall.", "none"),
    "JUN_FERN_B": ("Shared jungle", "models/jungle/jun_fern_cluster_low.glb", 25000, "Dense low cluster of jungle ferns and elephant ear leaves, 1.5 meters tall, 3 meters wide.", "none"),
    "JUN_BOULDER_A": ("Shared jungle", "models/jungle/jun_boulder_cluster_mossy_a.glb", 30000, "Cluster of three large mossy limestone boulders with ferns at base, 4 meters wide.", "convex"),
    "JUN_BOULDER_B": ("Shared jungle", "models/jungle/jun_boulder_cluster_split_b.glb", 30000, "Large split granite boulder pair with roots growing through crack, moss, 5 meters wide.", "convex"),
    "JUN_BOULDER_C": ("Shared jungle", "models/jungle/jun_boulder_ruin_mix_c.glb", 30000, VAELOR + "Pile of large weathered boulders mixed with fallen carved ruin blocks, moss, 5 meters wide.", "convex"),
    # Cave formation sets
    "CAV_STALACTITE_CLUSTER": ("Shared cave", "models/cave/cav_stalactite_ceiling_cluster.glb", 40000, "Dense cluster of hanging limestone stalactites of varied length from a rock ceiling slab, wet calcite, 5 meters wide.", "none (ceiling)"),
    "CAV_COLUMN": ("Shared cave", "models/cave/cav_flowstone_column.glb", 40000, "Massive cave flowstone column where stalactite meets stalagmite, rippled calcite drapery, 7 meters tall.", "capsule/convex"),
    "CAV_CLIFF_A": ("Shared cave", "models/cave/cav_limestone_cliff_a.glb", 50000, "Tall layered limestone cave cliff wall piece with ledges and cracks, 10 meters wide 8 meters tall, modular.", "trimesh(LOD3)"),
    "CAV_CLIFF_B": ("Shared cave", "models/cave/cav_limestone_cliff_b_overhang.glb", 50000, "Limestone cave cliff piece with deep overhang and climbable ledges, 8 meters wide, modular.", "trimesh(LOD3)"),
    "CAV_FLOWSTONE_WALL": ("Shared cave", "models/cave/cav_flowstone_drapery_wall.glb", 40000, "Cave wall section covered in flowstone curtains and drapery formations, wet, 6 meters wide.", "trimesh(LOD3)"),
    "CAV_CRYSTAL_A": ("Shared cave", "models/cave/cav_resonant_crystal_cluster_a.glb", 30000, "Cluster of large dark violet resonant crystals growing from cave rock, 2 meters tall.", "convex"),
    "CAV_CRYSTAL_B": ("Shared cave", "models/cave/cav_resonant_crystal_vein_b.glb", 30000, "Rock slab with a vein of embedded pale blue crystals and quartz points, 3 meters wide.", "convex"),
    "CAV_RIMSTONE_POOLS": ("Shared cave", "models/cave/cav_rimstone_pool_terrace.glb", 40000, "Cave rimstone dam terraces, stepped calcite pools without water, 5 meters wide.", "trimesh(LOD3) walkable"),
    # Meridian gear variants (attachable props, not new characters)
    "MER_GEAR_HELMET": ("Meridian", "models/meridian/mer_tactical_helmet_nvg.glb", 15000, "Modern tactical ballistic helmet with night vision mount and side rails, dark grey, no logos.", "none (attachment)"),
    "MER_GEAR_RIFLE": ("Meridian", "models/meridian/mer_assault_rifle.glb", 20000, "Generic modern tactical carbine rifle with optic and foregrip, black and dark grey, no brand markings.", "none (attachment)"),
    "MER_GEAR_HEAVY_ARMOR": ("Meridian", "models/meridian/mer_heavy_armor_vest.glb", 20000, "Heavy plate carrier armor vest with pouches and shoulder guards, dark grey, standalone, no person.", "none (attachment)"),
    "MER_GEAR_BACKPACK_RADIO": ("Meridian", "models/meridian/mer_radio_backpack.glb", 15000, "Military radio operator backpack with antenna, olive and black, standalone.", "none (attachment)"),
}


def load():
    return json.load(open(RECORDS)) if os.path.exists(RECORDS) else {}


def save(r):
    os.makedirs(os.path.dirname(RECORDS), exist_ok=True)
    tmp = RECORDS + ".tmp"
    json.dump(r, open(tmp, "w"), indent=2)
    os.replace(tmp, RECORDS)


def balance(slot):
    api.current_key_idx = slot - 1
    return api.make_request("/user/balance")["data"]["balance"]


def pick_slot(need=COST):
    for group in (PRIMARY, RESERVE):
        for s in group:
            try:
                if balance(s) >= need:
                    return s
            except Exception:
                continue
    return None


def submit(ids):
    r = load()
    for aid in ids:
        if r.get(aid, {}).get("status") in ("GENERATING", "DOWNLOADED", "ACCEPTED"):
            continue
        chapter, path, faces, prompt, coll = ASSETS[aid]
        slot = pick_slot()
        if slot is None:
            print("NO CREDITS for", aid)
            break
        api.current_key_idx = slot - 1
        payload = {"type": "text_to_model", "model_version": "P1-20260311", "prompt": STYLE + prompt,
                   "face_limit": faces, "texture": True, "pbr": True, "texture_quality": "standard"}
        res = None
        for fl in (faces, 30000, 20000):  # P1 rejects large face_limit values; step down
            payload["face_limit"] = min(fl, faces)
            try:
                res = api.make_request("/task", "POST", payload)
                break
            except urllib.error.HTTPError as e:
                err = e
        if res is None:
            e = err
            print(aid, "HTTP", e.code)
            r[aid] = {"status": "REJECTED", "reason": f"HTTP {e.code} on submit", "key_slot": slot}
            save(r)
            continue
        faces = payload["face_limit"]
        r[aid] = {"status": "GENERATING", "task_id": res["data"]["task_id"], "key_slot": slot,
                  "chapter": chapter, "path": "assets/" + path, "prompt": STYLE + prompt, "faces": faces,
                  "collision": coll, "retries": r.get(aid, {}).get("retries", 0)}
        save(r)
        print(aid, "submitted on slot", slot)


def poll():
    r = load()
    for aid, rec in r.items():
        if rec.get("status") != "GENERATING":
            continue
        api.current_key_idx = rec["key_slot"] - 1
        d = api.make_request("/task/" + rec["task_id"])["data"]
        st = d.get("status")
        if st == "success":
            out = d.get("output", {})
            url = out.get("pbr_model") or out.get("model")
            dest = os.path.join(ROOT, rec["path"])
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            urllib.request.urlretrieve(url, dest)
            rec.update(status="DOWNLOADED", consumed_credit=d.get("consumed_credit"))
            print(aid, "downloaded", os.path.getsize(dest))
        elif st in ("failed", "cancelled", "banned", "expired", "unknown"):
            rec.update(status="FAILED", reason=f"task {st} error_code {d.get('error_code')}", consumed_credit=d.get("consumed_credit"))
            print(aid, st)
    save(r)
    return sum(1 for v in r.values() if v.get("status") == "GENERATING")


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "submit":
        submit(sys.argv[2:] or list(ASSETS))
    elif cmd == "poll":
        while poll():
            time.sleep(15)
    elif cmd == "status":
        for k, v in load().items():
            print(k, v.get("status"), v.get("key_slot"), v.get("consumed_credit"), v.get("reason", ""))


def waves(max_inflight=10):
    """Submit in waves to respect Tripo concurrency limits (HTTP 429)."""
    while True:
        inflight = poll()
        r = load()
        pending = [a for a in ASSETS if r.get(a, {}).get("status") not in ("GENERATING", "DOWNLOADED", "ACCEPTED", "FAILED")
                   or (r[a].get("status") == "FAILED" and r[a].get("retries", 0) < 1)]
        if not pending and not inflight:
            return
        room = max_inflight - inflight
        for a in pending[:max(room, 0)]:
            if r.get(a, {}).get("status") == "FAILED":
                r[a]["retries"] = r[a].get("retries", 0) + 1
                save(r)
            submit([a])
        time.sleep(20)


if __name__ == "__main__" and sys.argv[1] == "waves":
    waves()
