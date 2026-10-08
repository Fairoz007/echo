"""Author the complete original campaign around playable, stable event beats."""
import csv
import json
import re
from collections import defaultdict
from pathlib import Path
from build_dialogue_registry import FIELDS

ROOT=Path(__file__).resolve().parents[1]
CHAPTERS={
 'C01':('THE ARRIVAL','Expedition camp and Eastern Ridge','72 hours earlier. Mara reunites with the expedition. Elias leads the research; Nadiya maintains communications; Tomas handles rescue; Adrian verifies survey coordinates. The portal confirms their hypothesis.'),
 'C02':('WHISPERS IN STONE','Waterfall ruin','A blocked sluice conceals a hydraulic counterweight. Mara restores the channel and reads a warning linking the ruins to a deeper acoustic network.'),
 'C03':('THE FALL','Ancient bridge over a fissure','The team crosses an unstable span. A tremor shears the anchors. Mara falls, separating her from the expedition and bringing the opening flash-forward into the present.'),
 'C04':('BENEATH','Collapsed caves','Mara survives in the fissure, follows air and water, and repairs her radio. Nadiya warns that Meridian forces have entered the valley.'),
 'C05':('HUNTERS','Meridian underground checkpoint','Mara conceals herself from armed contractors. Lucian Drake orders the aqueduct secured. She follows the flooding passage into the temple.'),
 'C06':('THE DROWNED TEMPLE','Submerged Vaelor sanctuary','The sanctuary is drowned by a diverted aqueduct. Mara lowers the water to expose the lower gate and discovers the city beyond.'),
 'C07':('CITY OF ECHOES','Lost underground city','The city reveals an entire civilization built around harmonic stone. A mural records the catastrophe; a side tomb shows counterweight engineering. The team waits at the forward camp.'),
 'C08':('THE BETRAYAL','Inner sanctum expedition refuge','Mara reunites with an injured Elias. Adrian has sold expedition coordinates to Meridian and stolen the Acoustic Key. His regret offers a route to the Heart Vault but does not erase his choice.'),
 'C09':('THE HEART ROAD','Unstable resonance conduits','Meridian blasting damages the harmonic conduits. Adrian provides the service route. Mara crosses collapsing infrastructure before Drake can activate the core.'),
 'C10':('THE HEART VAULT','Spherical resonant geode','Drake intends to weaponize the resonance network. Mara disrupts four harmonic nodes. Feedback breaks his control; she offers him escape before the chamber seals.'),
 'FIN':('THE MOUNTAIN BREAKS','Daylight fissure','Mara escapes through falling rock. Tomas pulls her onto the ridge. Nadiya and Elias survive; the sealed mountain becomes a protected archaeological site.'),
 'EPI':('DAYLIGHT','Surface ridge, dawn','The survivors choose preservation over extraction. Mara closes her journal. The expedition has evidence to protect the site without exposing its dangerous mechanism.')}

JOURNALS={
 'C01':"Field note. Waterfall chambers match the Vaelor survey. We document before we disturb.",
 'C02':"The inscription says the stone listens. These chambers carry sound like roads carry people.",
 'C03':"The bridge was built to move with the mountain. Someone cut its safety anchors.",
 'C04':"An old survey camp. They found this passage a century ago, then turned back.",
 'C05':"Meridian crates. This was planned before we opened the portal. Someone gave them our route.",
 'C06':"The temple's water channels regulate pressure. The flood is damage, not a trap.",
 'C07':"They left the warning where everyone could see it. We should listen to the people who lived here.",
 'C08':"Elias trusted Adrian's survey. So did I. Trust is not proof; the transmission log is.",
 'C09':"The Heart Road carries the city's resonance. Every blast travels farther than they know.",
 'C10':"Four nodes hold the network in balance. Break the feedback, and Drake loses the core."}

def main():
    rows=[]; events={}; counts=defaultdict(int)
    def add(chapter,event,speaker,text,alias=None,radio=False):
        key=(chapter,speaker);counts[key]+=1
        dialogue_id=f'{chapter}_{speaker}_{counts[key]:03d}'
        row=dict(zip(FIELDS,[dialogue_id,chapter,f'{chapter}-{event.upper()}',speaker,text,
            'controlled urgency' if chapter in {'C03','C09','C10','FIN'} else 'grounded curiosity',
            'high' if chapter in {'C03','FIN'} else 'medium',
            'restrained natural performance','Yes' if radio else 'No','Yes' if event in {'opening','exit','confrontation','ending'} else 'No',
            'Yes','Yes','high',f'res://audio/dialogue/{speaker.lower()}/VO_{dialogue_id}.wav','PLANNED']))
        rows.append(row)
        events.setdefault(chapter,{}).setdefault(event,[]).append(dialogue_id)
        aliases[alias or text]=dialogue_id
        return dialogue_id
    aliases={}
    pro=["Ugh... Still breathing. Radio... Nadiya? Elias? Anyone?","Right. Up. One step at a time.","This stone... it's vibrating. Not from seismic tremors. It's humming.","What did we find?"]
    for index,text in enumerate(pro):
        add('PRO','opening' if index<2 else 'glyph' if index==2 else 'exit','MARA',text)
    pattern=re.compile(r'(?:hud\.show_subtitle|AudioManager\.play_story_line)\("((?:\\.|[^"\\])*)", "((?:\\.|[^"\\])*)", ([\d.]+)\)')
    for file in [*(ROOT/'levels').glob('Chapter*.gd'),ROOT/'levels/Finale.gd']:
        chapter='FIN' if file.stem=='Finale' else f'C{int(file.stem.removeprefix("Chapter")):02d}'
        source=file.read_text(encoding='utf-8-sig')
        method='opening'
        for line in source.splitlines():
            if line.startswith('func '):method=line.split('(')[0].removeprefix('func ').removeprefix('_on_')
            match=pattern.search(line)
            if not match:continue
            speaker=json.loads('"'+match[1]+'"');legacy=json.loads('"'+match[2]+'"')
            character=speaker.split(' (')[0].upper()
            text=legacy.strip('"').removeprefix('Tomas: ')
            if chapter=='C01' and text.startswith('Three days late'):text='You made it, Mara. Elias is waiting by the survey table.'
            if chapter=='C08' and character=='ADRIAN':text="I'm sorry, Mara. I sold the coordinates, not your lives. Drake took the Key. Use the service road."
            if chapter=='FIN' and text=='Never again...':text='We leave the core here. No one gets to turn their history into a weapon.'
            add(chapter,'opening' if method=='_ready' else method,character,text,legacy,'Radio' in speaker)
    for chapter,text in JOURNALS.items():add(chapter,'journal','MARA',text)
    add('C01','team','TOMAS','Climbing kit is checked. If the weather turns, we come back together.')
    add('C01','team','ADRIAN','The eastern contour is verified. I will keep the survey beacon running.')
    add('C05','patrol','MERIDIAN','Hold the lower passage. No one enters without clearance.')
    add('C08','aftermath','MARA','You gave him the way in. Help us get everyone out.')
    add('C08','aftermath','ELIAS','The Key opens the Vault, Mara. The four outer nodes can still stop it.')
    add('C10','warning','MARA','The Vaelor sealed this place for a reason. You are repeating their mistake.')
    add('C10','warning','DRAKE','They lacked control. We have the instruments to finish what they began.')
    add('FIN','rescue','NADIYA','Elias is clear. Tomas, get her away from the edge!')
    add('EPI','ending','ELIAS','We came looking for a discovery. You reminded us what we owe it.')
    add('EPI','ending','MARA','The survey will prove the site exists. Its location stays protected.')
    add('EPI','ending','MARA','Some stories survive because we leave them where they belong.')
    with (ROOT/'DIALOGUE_PRODUCTION.csv').open('w',newline='',encoding='utf-8') as handle:
        writer=csv.DictWriter(handle,fieldnames=FIELDS);writer.writeheader();writer.writerows(rows)
    (ROOT/'audio/campaign_events.json').write_text(json.dumps({'events':events,'aliases':aliases},indent=2),encoding='utf-8')
    script=['# COMPLETE SCREENPLAY: ECHOES BENEATH','','Original production screenplay. Cast: Mara Vale, Dr. Elias Voss, Nadiya Rahman, Tomas Reyes, Adrian Kell, Lucian Drake, Meridian Commander. Adrian is the betrayer; Elias survives as Mara\'s mentor.','','## PROLOGUE: THE DESCENT','','Flash-forward. Mara wakes beneath the mountain, regains control and discovers the resonant glyph. The title cuts to 72 hours earlier.']
    for chapter in ['PRO',*CHAPTERS]:
        if chapter!='PRO':
            title,location,action=CHAPTERS[chapter];script += ['',f'## {chapter}: {title}','',f'**LOCATION:** {location}','',f'[{action}]']
        for event,ids in events.get(chapter,{}).items():
            script += ['',f'### SCENE {chapter}-{event.upper()}','',f'[Playable event: {event}. Dialogue follows the action and leaves room for environmental sound.]']
            for dialogue_id in ids:
                row=next(r for r in rows if r['Dialogue ID']==dialogue_id)
                script += ['',f"{row['Character']}  ",f"({row['Emotion']}; {'radio' if row['Radio?']=='Yes' else 'in scene'})  ",row['Text']]
    (ROOT/'COMPLETE_SCREENPLAY.md').write_text('\n'.join(script)+'\n',encoding='utf-8')
    print(json.dumps({'lines':len(rows),'characters':sum(len(row['Text']) for row in rows),'events':{k:list(v) for k,v in events.items()}}))

if __name__=='__main__':main()
