"""Seed the Disease knowledge base for the classes the ML models predict.

Covers all three species with a configured model in core/views.py:
Tomato (10 classes), Potato (3) and Bell Pepper (2). `label` values mirror
exactly the CLASS_NAMES lists the models output, and are the join key.

Idempotent: re-running updates existing rows (keyed on `label`) rather than
duplicating.

Reference photos are shipped as bundled static files under
core/static/library/diseases/<label>.jpg (curated from Wikimedia Commons — see
the `# image:` attribution comment on each entry). `image_urls` therefore holds
static-relative paths; the serializer resolves them to /static/ URLs.

Data sources (consulted at authoring time, not at runtime):
  - PlantVillage — https://plantvillage.psu.edu/
  - University of Minnesota Extension — https://extension.umn.edu/diseases
  - Penn State Extension — https://extension.psu.edu/
  - Cornell Vegetable MD Online — https://www.vegetables.cornell.edu/
  - Wikipedia — general descriptions / pathogen names.

Run: python manage.py seed_diseases
(Requires the species to exist — run seed_species first.)
"""

from django.core.management.base import BaseCommand
from core.models import Disease, PlantSpecies


# One entry per class the models predict. `label` is the join key; `species`
# is the PlantSpecies.name it belongs to (resolved to a row in handle()).
DISEASES = [
    # ─── Tomato ──────────────────────────────────────────────────
    dict(
        label='Tomato_Bacterial_spot',
        species='Tomato',
        name='Bacterial Spot',
        severity=Disease.Severity.HIGH,
        # No suitable free tomato bacterial-spot photo exists on Wikimedia
        # Commons (the bacterial-spot image there is on pepper, and belongs to
        # the Pepper entry). Left imageless — the app shows a placeholder.
        image_urls=[],
        description=(
            'Bacterial spot is a common, fast-spreading disease that attacks '
            'the leaves, stems and fruit of tomatoes in warm, wet weather. It '
            'is carried on infected seed and transplants and moves from plant '
            'to plant through rain splash, overhead watering and handling. '
            'Left unchecked it causes leaves to yellow and drop and leaves '
            'scabby lesions on fruit, cutting yield and making fruit '
            'unmarketable. Caught early and managed with sanitation and copper '
            'sprays plants can still crop, but the bacterium is very hard to '
            'eradicate once established.'
        ),
        symptoms=(
            'Small, water-soaked spots on leaves that turn dark brown to black '
            'with a yellow halo. Spots may merge, causing leaves to yellow and '
            'drop. Raised, scabby spots appear on green fruit.'
        ),
        cause=(
            'Bacteria in the Xanthomonas group, spread by rain splash, '
            'overhead irrigation, handling, and infected seed or transplants. '
            'Favoured by temperatures of 24-30C and high humidity.'
        ),
        treatment=(
            'Remove and destroy infected leaves and fruit. Copper-based '
            'sprays can slow spread when applied early and repeatedly, but do '
            'not cure infected tissue. Avoid working among wet plants.'
        ),
        care_tips=(
            'Water at the base in the morning so foliage dries quickly. Space '
            'plants for airflow and rotate away from tomatoes/peppers for 2-3 '
            'years. Start with certified disease-free seed and transplants.'
        ),
        prevention=(
            'Use disease-free seed, rotate crops, avoid overhead watering, and '
            'sanitise tools and hands after handling infected plants.'
        ),
        source_name='University of Minnesota Extension',
        source_url='https://extension.umn.edu/disease-management/bacterial-spot-tomato-and-pepper',
    ),
    dict(
        label='Tomato_Early_blight',
        species='Tomato',
        name='Early Blight',
        severity=Disease.Severity.MEDIUM,
        # image: commons.wikimedia.org/wiki/File:Alternaria_solani_-_leaf_lesions.jpg
        image_urls=['library/diseases/Tomato_Early_blight.jpg'],
        description=(
            'Early blight is a widespread fungal disease that usually begins '
            'on the oldest, lowest leaves and works its way up the plant. The '
            'fungus survives in soil and plant debris and spreads by wind, '
            'water splash and tools, especially in warm, humid spells. As the '
            'lower leaves die back the fruit loses its canopy and becomes '
            'prone to sunscald, steadily weakening the plant. It rarely kills '
            'a tomato outright, and prompt leaf removal plus fungicide keeps '
            'it manageable through the season.'
        ),
        symptoms=(
            'Brown spots with concentric rings ("target" or bullseye pattern) '
            'surrounded by a yellow zone, mostly on lower leaves. Affected '
            'leaves yellow and fall; dark sunken lesions can form on stems and '
            'fruit near the stem.'
        ),
        cause=(
            'The fungus Alternaria solani, which overwinters in plant debris '
            'and soil. Spread by wind, water splash and tools; favoured by '
            'warm, humid conditions and stressed plants.'
        ),
        treatment=(
            'Pick off and destroy affected leaves at first sign. Apply a '
            'fungicide (chlorothalonil, mancozeb, or copper) on a schedule in '
            'humid weather. Mulch to stop soil splashing onto leaves.'
        ),
        care_tips=(
            'Keep plants vigorous with steady watering and balanced feeding. '
            'Stake and prune for airflow, water at the base, and clear all '
            'debris at the end of the season.'
        ),
        prevention=(
            'Rotate crops, mulch, space plants well, and choose resistant '
            'varieties. Remove volunteer tomatoes and nightshade weeds.'
        ),
        source_name='University of Minnesota Extension',
        source_url='https://extension.umn.edu/disease-management/early-blight-tomato-and-potato',
    ),
    dict(
        label='Tomato_Late_blight',
        species='Tomato',
        name='Late Blight',
        severity=Disease.Severity.HIGH,
        # image: commons.wikimedia.org/wiki/File:Late_blight_on_potato_leaf_2.jpg
        image_urls=['library/diseases/Tomato_Late_blight.jpg'],
        description=(
            'Late blight is an aggressive, fast-moving disease — the same one '
            'behind the Irish potato famine — that can destroy a tomato crop '
            'within days. Its spores travel long distances on wind and rain, '
            'so an outbreak nearby can reach your garden quickly in cool, wet '
            'weather. Infected leaves and fruit rot rapidly, and heavily hit '
            'plants seldom recover. Because it spreads so fast, success '
            'depends on early detection, removing infected plants immediately '
            'and protecting healthy ones before symptoms appear.'
        ),
        symptoms=(
            'Large, greasy-looking grey-green blotches on leaves that quickly '
            'turn brown; white fuzzy mould on leaf undersides in humid '
            'conditions. Firm, greasy brown lesions develop on fruit.'
        ),
        cause=(
            'The water mould Phytophthora infestans, spread rapidly by wind '
            'and rain over long distances. Thrives in cool (10-24C), wet, '
            'humid weather.'
        ),
        treatment=(
            'Act immediately: remove and bag infected plants to stop spread. '
            'Protective fungicides (chlorothalonil or copper) help nearby '
            'healthy plants but cannot save heavily infected ones.'
        ),
        care_tips=(
            'Improve airflow, avoid overhead watering, and inspect plants '
            'daily during cool, damp spells. Never compost infected plants.'
        ),
        prevention=(
            'Plant resistant varieties, use certified seed potatoes/transplants, '
            'destroy cull piles and volunteers, and monitor regional blight '
            'alerts.'
        ),
        source_name='Cornell Vegetable MD Online',
        source_url='https://www.vegetables.cornell.edu/pest-management/disease-factsheets/late-blight/',
    ),
    dict(
        label='Tomato_Leaf_Mold',
        species='Tomato',
        name='Leaf Mold',
        severity=Disease.Severity.MEDIUM,
        # image: commons.wikimedia.org/wiki/File:TomateBlattOberseiteSamtfleckenCladosporiumfulvum.jpg
        image_urls=['library/diseases/Tomato_Leaf_Mold.jpg'],
        description=(
            'Leaf mold is a fungal disease that thrives where air is still and '
            'humidity stays high, so it is most common in greenhouses, high '
            'tunnels and crowded plantings. Spores spread easily on air '
            'currents, tools and clothing whenever leaves stay damp. Infected '
            'foliage yellows, curls and drops, and the loss of leaves reduces '
            'fruit set and size. It is rarely fatal and responds well to '
            'better ventilation, lower humidity and early leaf removal.'
        ),
        symptoms=(
            'Pale green to yellow spots on the upper leaf surface, with olive-'
            'green to brown velvety mould on the undersides. Leaves curl, wither '
            'and drop, reducing fruiting.'
        ),
        cause=(
            'The fungus Passalora fulva (Cladosporium fulvum), favoured by '
            'relative humidity above 85% and moderate temperatures. Spores '
            'spread on air currents, tools and clothing.'
        ),
        treatment=(
            'Remove affected leaves and improve ventilation immediately. Apply '
            'a labelled fungicide if it spreads. Reduce humidity by venting and '
            'spacing plants.'
        ),
        care_tips=(
            'Keep relative humidity down, water early in the day at the base, '
            'and prune lower foliage to open up the canopy.'
        ),
        prevention=(
            'Grow resistant varieties, maximise airflow and venting in '
            'protected culture, and avoid wetting leaves.'
        ),
        source_name='Cornell Vegetable MD Online',
        source_url='https://www.vegetables.cornell.edu/pest-management/disease-factsheets/leaf-mold-of-tomato/',
    ),
    dict(
        label='Tomato_Septoria_leaf_spot',
        species='Tomato',
        name='Septoria Leaf Spot',
        severity=Disease.Severity.MEDIUM,
        # image: commons.wikimedia.org/wiki/File:Septoria_lycopersici_malagutii_leaf_spot_on_tomato_leaf.jpg
        image_urls=['library/diseases/Tomato_Septoria_leaf_spot.jpg'],
        description=(
            'Septoria leaf spot is one of the most common tomato leaf '
            'diseases, causing heavy defoliation but not infecting the fruit '
            'directly. The fungus overwinters in debris and on weeds and '
            'spreads by splashing water during warm, wet weather, starting low '
            'on the plant and climbing. As leaves are stripped away the '
            'exposed fruit is prone to sunscald and the plant weakens. '
            'Removing affected leaves early and keeping foliage dry usually '
            'keeps it in check for the rest of the season.'
        ),
        symptoms=(
            'Many small, circular spots with dark brown borders and tan-grey '
            'centres, often dotted with tiny black specks (fruiting bodies). '
            'Starts on lower leaves and spreads upward.'
        ),
        cause=(
            'The fungus Septoria lycopersici, which survives in debris and on '
            'weeds. Spread by splashing water; favoured by warm, wet, humid '
            'weather.'
        ),
        treatment=(
            'Remove infected lower leaves early and destroy them. Apply '
            'chlorothalonil or copper fungicide on a regular schedule during '
            'wet weather. Mulch to reduce splash.'
        ),
        care_tips=(
            'Water at the base in the morning, stake plants for airflow, and '
            'remove debris and weeds that harbour the fungus.'
        ),
        prevention=(
            'Rotate crops for 1-2 years, mulch, control nightshade weeds, and '
            'clean up all plant debris at season end.'
        ),
        source_name='University of Minnesota Extension',
        source_url='https://extension.umn.edu/disease-management/septoria-leaf-spot-tomato',
    ),
    dict(
        label='Tomato_Spider_mites_Two_spotted_spider_mite',
        species='Tomato',
        name='Two-Spotted Spider Mites',
        severity=Disease.Severity.MEDIUM,
        # image: commons.wikimedia.org/wiki/File:Tetranychus_urticae_(4883560779).jpg
        image_urls=['library/diseases/Tomato_Spider_mites_Two_spotted_spider_mite.jpg'],
        description=(
            'Two-spotted spider mites are tiny sap-sucking pests, not a '
            'disease, that multiply explosively in hot, dry conditions. They '
            'colonise the undersides of leaves and can build from a few mites '
            'to a damaging infestation in just days. Their feeding gives '
            'leaves a bronzed, dusty, stippled look and, in bad cases, fine '
            'webbing before leaves dry out and drop. Rinsing plants, raising '
            'humidity and treating early with soap or oil usually brings them '
            'under control before they stunt the plant.'
        ),
        symptoms=(
            'Fine yellow or white stippling (tiny dots) on leaves, giving a '
            'bronzed, dusty look. Fine webbing on leaf undersides and tips in '
            'heavy infestations; leaves dry out and drop.'
        ),
        cause=(
            'The two-spotted spider mite (Tetranychus urticae), a tiny arachnid '
            'that thrives in hot, dry, dusty conditions and reproduces rapidly.'
        ),
        treatment=(
            'Spray plants forcefully with water to knock mites off, then treat '
            'with insecticidal soap or horticultural/neem oil, covering leaf '
            'undersides. Repeat every few days. Remove badly infested leaves.'
        ),
        care_tips=(
            'Keep plants well watered and not heat-stressed, raise humidity, '
            'and rinse dust off foliage. Encourage natural predators like '
            'ladybirds and predatory mites.'
        ),
        prevention=(
            'Avoid drought stress, inspect leaf undersides regularly, and avoid '
            'broad-spectrum insecticides that kill mite predators.'
        ),
        source_name='University of Minnesota Extension',
        source_url='https://extension.umn.edu/yard-and-garden-insects/spider-mites',
    ),
    dict(
        label='Tomato__Target_Spot',
        species='Tomato',
        name='Target Spot',
        severity=Disease.Severity.MEDIUM,
        # image: commons.wikimedia.org/wiki/File:Corynespora_cassiicola_Ring-Spot_Symptoms_in_Tomato_Leaves.png
        image_urls=['library/diseases/Tomato__Target_Spot.jpg'],
        description=(
            'Target spot is a fungal disease of the leaves, stems and fruit '
            'that is most damaging in warm, humid and tropical climates. The '
            'fungus spreads by wind and water splash and is favoured by long '
            'periods of leaf wetness. Spots enlarge into ringed lesions that '
            'merge and defoliate the plant, while sunken cracks on the fruit '
            'can cause significant losses. Improving airflow and applying '
            'protective fungicide early keeps the disease from taking hold.'
        ),
        symptoms=(
            'Small brown spots that enlarge into lesions with concentric rings '
            'and a light centre on leaves. Sunken, circular spots with '
            'cracked centres develop on fruit.'
        ),
        cause=(
            'The fungus Corynespora cassiicola, spread by wind and water '
            'splash. Favoured by extended leaf wetness and warm, humid weather.'
        ),
        treatment=(
            'Remove affected foliage and fruit. Apply a protective fungicide '
            '(chlorothalonil or mancozeb) when conditions favour disease, '
            'covering the whole canopy.'
        ),
        care_tips=(
            'Improve airflow with staking and pruning, water at the base early '
            'in the day, and mulch to limit soil splash.'
        ),
        prevention=(
            'Rotate crops, space plants generously, remove debris, and use '
            'resistant varieties where available.'
        ),
        source_name='PlantVillage (Penn State)',
        source_url='https://plantvillage.psu.edu/topics/tomato/infos',
    ),
    dict(
        label='Tomato__Tomato_YellowLeaf__Curl_Virus',
        species='Tomato',
        name='Tomato Yellow Leaf Curl Virus',
        severity=Disease.Severity.HIGH,
        # image: commons.wikimedia.org/wiki/File:Yellow_curl_leaf_disease_Pj_IMG_3162.jpg
        image_urls=['library/diseases/Tomato__Tomato_YellowLeaf__Curl_Virus.jpg'],
        description=(
            'Tomato yellow leaf curl virus is a serious viral disease spread '
            'by whiteflies that can devastate a crop, especially when plants '
            'are infected while young. The virus itself does not spread by '
            'seed or simple touch — it moves only when whiteflies feed — so '
            'controlling the insect is central to managing it. Infected plants '
            'become stunted and bushy with upward-curling, yellow-edged leaves '
            'and drop most of their flowers, setting little or no fruit. There '
            'is no cure once a plant is infected, so prevention through '
            'whitefly control and resistant varieties is essential.'
        ),
        symptoms=(
            'Upward curling and cupping of leaves, yellowing of leaf margins, '
            'stunted bushy growth, and heavy flower drop. Infected young plants '
            'may set little or no fruit.'
        ),
        cause=(
            'Tomato yellow leaf curl virus (TYLCV), transmitted by the '
            'silverleaf/sweetpotato whitefly (Bemisia tabaci). The virus is not '
            'spread by seed or simple contact.'
        ),
        treatment=(
            'There is no cure once a plant is infected. Remove and bag infected '
            'plants promptly to limit a whitefly reservoir, and focus on '
            'controlling whiteflies on remaining plants.'
        ),
        care_tips=(
            'Manage whiteflies with insecticidal soap, oils, or reflective '
            'mulch, and use fine insect netting on young plants. Inspect leaf '
            'undersides for whiteflies regularly.'
        ),
        prevention=(
            'Plant resistant varieties, use whitefly-proof netting and '
            'reflective mulch, control weeds that host whiteflies, and remove '
            'infected plants early.'
        ),
        source_name='University of Florida IFAS Extension',
        source_url='https://edis.ifas.ufl.edu/publication/IN1271',
    ),
    dict(
        label='Tomato__Tomato_mosaic_virus',
        species='Tomato',
        name='Tomato Mosaic Virus',
        severity=Disease.Severity.MEDIUM,
        # image: commons.wikimedia.org/wiki/File:Leaf_with_ToMV.jpg
        image_urls=['library/diseases/Tomato__Tomato_mosaic_virus.jpg'],
        description=(
            'Tomato mosaic virus is a highly contagious and unusually stable '
            'virus that spreads by touch, on tools and on hands rather than by '
            'insects. It can survive for long periods on surfaces, in debris '
            'and in seed, so it moves easily from plant to plant during '
            'routine handling. Infected plants show mottled leaves, distorted '
            'growth and reduced vigour, and fruit quality and yield suffer. '
            'There is no cure, but strict sanitation — clean hands, '
            'disinfected tools and prompt removal of infected plants — reliably '
            'stops it spreading.'
        ),
        symptoms=(
            'Mottled light- and dark-green (mosaic) patterns on leaves, leaf '
            'curling or fern-like distortion, stunted growth, and sometimes '
            'mottling or internal browning of fruit.'
        ),
        cause=(
            'Tomato mosaic virus (ToMV), spread mechanically through handling, '
            'tools, infected debris and seed. The virus can survive for long '
            'periods on surfaces and in plant material.'
        ),
        treatment=(
            'There is no cure. Remove and destroy infected plants, then wash '
            'hands and disinfect tools thoroughly to stop spread to healthy '
            'plants.'
        ),
        care_tips=(
            'Avoid handling plants when wet, do not use tobacco products near '
            'plants, and sanitise tools, stakes and hands between plants.'
        ),
        prevention=(
            'Use certified virus-free seed and resistant varieties, sanitise '
            'everything that touches plants, and remove infected plants and '
            'debris promptly.'
        ),
        source_name='Wikipedia',
        source_url='https://en.wikipedia.org/wiki/Tomato_mosaic_virus',
    ),
    dict(
        label='Tomato_healthy',
        species='Tomato',
        name='Healthy',
        severity=Disease.Severity.LOW,
        # image: commons.wikimedia.org/wiki/File:Tomato_je.jpg
        image_urls=['library/diseases/Tomato_healthy.jpg'],
        description=(
            'No disease was detected — the leaf looks healthy, with normal '
            'colour and shape and no signs of spots, mould, curling or pests. '
            'A healthy tomato reflects good growing conditions: steady water, '
            'balanced feeding, full sun and open airflow. Keeping up a '
            'consistent care routine is the best way to keep plants resilient. '
            'Continue checking leaf undersides each week so any early problem '
            'is caught before it spreads.'
        ),
        symptoms=(
            'Uniform green leaves, firm stems, and steady new growth, with no '
            'spots, yellowing, wilting, webbing or distortion.'
        ),
        cause=(
            'A healthy plant reflects good growing conditions: appropriate '
            'light, water, nutrients, airflow and pest-free foliage.'
        ),
        treatment=(
            'No treatment needed. Keep up your regular care routine and '
            'continue monitoring for any early signs of trouble.'
        ),
        care_tips=(
            'Water consistently at the base, feed during the growing season, '
            'ensure good airflow and full sun, and check leaf undersides '
            'weekly to catch any problems early.'
        ),
        prevention=(
            'Maintain crop rotation, good spacing, clean tools and steady '
            'watering to keep plants resilient against disease and pests.'
        ),
        source_name='University of Minnesota Extension',
        source_url='https://extension.umn.edu/vegetables/growing-tomatoes',
    ),

    # ─── Potato ──────────────────────────────────────────────────
    dict(
        label='Potato___Early_blight',
        species='Potato',
        name='Early Blight',
        severity=Disease.Severity.MEDIUM,
        # image: commons.wikimedia.org/wiki/File:Alternaria_solani_IMG_1661.jpg
        image_urls=['library/diseases/Potato___Early_blight.jpg'],
        description=(
            'Early blight is a common fungal disease of potatoes that '
            'typically appears first on the older, lower leaves as the plant '
            'matures. The fungus overwinters in soil and crop debris and '
            'spreads by wind and water splash during warm, humid weather. '
            'Severe infections defoliate the plant, reducing tuber size and '
            'yield, and the fungus can also cause dry, sunken lesions on '
            'tubers. Potatoes that are well fed and watered tolerate it '
            'better, and early leaf removal with timely fungicide keeps losses '
            'low.'
        ),
        symptoms=(
            'Dark brown spots with concentric rings (a "target" pattern) '
            'surrounded by yellowing, mostly on older lower leaves. Spots '
            'enlarge and merge until leaves die and drop. Tubers may develop '
            'dark, sunken, corky lesions.'
        ),
        cause=(
            'The fungus Alternaria solani, which survives in soil and infected '
            'debris. Spread by wind, splashing water and tools, and favoured '
            'by warm temperatures, dew and ageing or stressed plants.'
        ),
        treatment=(
            'Remove and destroy affected leaves as symptoms begin. Apply a '
            'protective fungicide (chlorothalonil or mancozeb) on a schedule '
            'in warm, humid weather. Keep plants vigorous with adequate water '
            'and nitrogen to slow the disease.'
        ),
        care_tips=(
            'Hill soil over tubers to protect them, water at the base early in '
            'the day, and avoid working among wet plants. Cure and store only '
            'sound, undamaged tubers.'
        ),
        prevention=(
            'Rotate away from potatoes and tomatoes for 2-3 years, use '
            'certified seed potatoes, space plants for airflow, and clean up '
            'all debris after harvest.'
        ),
        source_name='University of Minnesota Extension',
        source_url='https://extension.umn.edu/disease-management/early-blight-tomato-and-potato',
    ),
    dict(
        label='Potato___Late_blight',
        species='Potato',
        name='Late Blight',
        severity=Disease.Severity.HIGH,
        # image: commons.wikimedia.org/wiki/File:Potato_Late_Blight.JPG
        image_urls=['library/diseases/Potato___Late_blight.jpg'],
        description=(
            'Late blight is the most destructive disease of potatoes — the '
            'cause of the Irish potato famine — and can wipe out a crop within '
            'days in cool, wet weather. The pathogen spreads rapidly on wind '
            'and rain over long distances, so regional outbreaks reach gardens '
            'fast. It rots foliage and produces a reddish-brown dry rot in '
            'tubers that keeps spreading in storage. Because it moves so '
            'quickly, control depends on early detection, destroying infected '
            'plants and protecting healthy foliage before symptoms show.'
        ),
        symptoms=(
            'Large, dark, greasy-looking blotches on leaves and stems that '
            'rapidly turn brown, often with a ring of white mould on leaf '
            'undersides in humid conditions. Tubers develop a reddish-brown, '
            'granular dry rot beneath the skin.'
        ),
        cause=(
            'The water mould Phytophthora infestans, spread rapidly by '
            'wind-blown spores and rain. Thrives in cool (10-24C), wet, humid '
            'weather and survives between seasons in infected tubers and cull '
            'piles.'
        ),
        treatment=(
            'Act immediately: remove and bag infected plants to stop spread, '
            'and never compost them. Protective fungicides (chlorothalonil or '
            'copper) shield nearby healthy plants but cannot cure infected '
            'ones. Kill off foliage before harvest so tubers are not infected '
            'at lifting.'
        ),
        care_tips=(
            'Hill tubers well so spores cannot wash down to them, improve '
            'airflow, and inspect daily in cool, damp spells. Store only dry, '
            'sound tubers and check them regularly.'
        ),
        prevention=(
            'Plant certified disease-free seed potatoes and resistant '
            'varieties, destroy cull piles and volunteers, avoid overhead '
            'watering, and monitor regional blight alerts.'
        ),
        source_name='University of Minnesota Extension',
        source_url='https://extension.umn.edu/disease-management/late-blight',
    ),
    dict(
        label='Potato___healthy',
        species='Potato',
        name='Healthy',
        severity=Disease.Severity.LOW,
        # image: commons.wikimedia.org/wiki/File:20210731_Hortus_botanicus_Leiden_-_Solanum_tuberosum.jpg
        image_urls=['library/diseases/Potato___healthy.jpg'],
        description=(
            'No disease was detected — the potato foliage looks healthy, with '
            'uniform green leaves and no spots, mould, wilting or pest damage. '
            'Healthy plants reflect good growing conditions: loose, '
            'well-drained soil, steady moisture, full sun and proper hilling. '
            'A vigorous canopy feeds the developing tubers and shrugs off '
            'minor stress. Keep up a consistent routine and scout regularly so '
            'any problem is caught early.'
        ),
        symptoms=(
            'Uniform green leaves, sturdy upright stems and steady new growth, '
            'with no spots, yellowing, wilting or leaf curling.'
        ),
        cause=(
            'A healthy potato reflects good conditions: fertile, well-drained '
            'soil, consistent watering, full sun, adequate hilling and '
            'pest-free foliage.'
        ),
        treatment=(
            'No treatment needed. Continue your normal watering, feeding and '
            'hilling routine and keep monitoring for early signs of trouble.'
        ),
        care_tips=(
            'Hill soil around stems as they grow to protect tubers from light '
            'and disease, water evenly to prevent cracking, and stop watering '
            'as foliage yellows so skins can set.'
        ),
        prevention=(
            'Use certified seed potatoes, rotate crops, space plants for '
            'airflow, and clear debris at season end to keep plants resilient.'
        ),
        source_name='University of Minnesota Extension',
        source_url='https://extension.umn.edu/vegetables/growing-potatoes',
    ),

    # ─── Bell Pepper ─────────────────────────────────────────────
    dict(
        label='Pepper__bell___Bacterial_spot',
        species='Bell Pepper',
        name='Bacterial Spot',
        severity=Disease.Severity.HIGH,
        # image: commons.wikimedia.org/wiki/File:Bacterial_leaf_spot_on_pepper.jpg
        image_urls=['library/diseases/Pepper__bell___Bacterial_spot.jpg'],
        description=(
            'Bacterial spot is the most serious bacterial disease of peppers, '
            'attacking the leaves and fruit in warm, wet weather. It arrives '
            'on infected seed and transplants and spreads plant to plant '
            'through rain splash, overhead irrigation and handling. Heavy '
            'infection causes leaves to yellow and drop, exposing fruit to '
            'sunscald and leaving raised, scabby spots that make peppers '
            'unmarketable. It cannot be cured once established, so early '
            'sanitation, copper sprays and clean seed are the keys to keeping '
            'a crop.'
        ),
        symptoms=(
            'Small, water-soaked spots on leaves that turn dark brown to black, '
            'sometimes with a yellow halo; badly spotted leaves yellow and '
            'drop. Raised, scabby, corky spots develop on the fruit.'
        ),
        cause=(
            'Bacteria in the Xanthomonas group, spread by rain splash, '
            'overhead watering, handling and infected seed or transplants. '
            'Favoured by temperatures of 24-30C and high humidity.'
        ),
        treatment=(
            'Remove and destroy infected leaves and fruit. Copper-based sprays '
            'can slow spread when applied early and repeatedly but do not cure '
            'infected tissue. Avoid working among wet plants.'
        ),
        care_tips=(
            'Water at the base in the morning so foliage dries quickly, space '
            'plants for airflow, and rotate away from peppers and tomatoes for '
            '2-3 years. Start with certified disease-free seed and transplants.'
        ),
        prevention=(
            'Use disease-free seed, rotate crops, avoid overhead watering, and '
            'sanitise tools and hands after handling infected plants.'
        ),
        source_name='University of Minnesota Extension',
        source_url='https://extension.umn.edu/disease-management/bacterial-spot-tomato-and-pepper',
    ),
    dict(
        label='Pepper__bell___healthy',
        species='Bell Pepper',
        name='Healthy',
        severity=Disease.Severity.LOW,
        # image: commons.wikimedia.org/wiki/File:Bell_Pepper_Plant_from_Senegal_03.jpg
        image_urls=['library/diseases/Pepper__bell___healthy.jpg'],
        description=(
            'No disease was detected — the pepper plant looks healthy, with '
            'firm green leaves and no spots, wilting, curling or pest damage. '
            'Healthy peppers reflect warm conditions, full sun, steady water '
            'and balanced feeding. A strong plant sets and ripens thick-walled '
            'fruit and resists most problems. Keep up a consistent routine and '
            'check leaf undersides weekly so any issue is caught early.'
        ),
        symptoms=(
            'Firm, uniform green leaves, sturdy branching stems and steady '
            'flowering and fruit set, with no spots, yellowing, wilting or '
            'distortion.'
        ),
        cause=(
            'A healthy pepper reflects good conditions: warmth, full sun, '
            'consistent watering, balanced feeding and pest-free foliage.'
        ),
        treatment=(
            'No treatment needed. Continue steady watering and feeding through '
            'the warm season and keep monitoring for early signs of trouble.'
        ),
        care_tips=(
            'Water evenly to prevent blossom-end rot, feed during fruiting, '
            'stake heavy plants, and pick the first fruits early to boost '
            'overall yield.'
        ),
        prevention=(
            'Rotate crops, space plants for airflow, use clean seed and '
            'transplants, and clear debris at season end to keep plants '
            'resilient.'
        ),
        source_name='University of Minnesota Extension',
        source_url='https://extension.umn.edu/vegetables/growing-peppers',
    ),
]


class Command(BaseCommand):
    help = 'Seed the Disease knowledge base for all model classes (idempotent).'

    def handle(self, *args, **options):
        species_by_name = {s.name: s for s in PlantSpecies.objects.all()}
        needed = {spec['species'] for spec in DISEASES}
        missing = needed - set(species_by_name)
        if missing:
            self.stderr.write(self.style.ERROR(
                f'Missing species {sorted(missing)}. '
                'Run `python manage.py seed_species` first.'
            ))
            return

        created = 0
        updated = 0
        for spec in DISEASES:
            # Copy (don't pop) so re-running in the same process — e.g. from
            # tests — doesn't mutate the module-level dicts.
            defaults = {
                k: v for k, v in spec.items()
                if k not in ('label', 'species')
            }
            defaults['species'] = species_by_name[spec['species']]
            obj, was_created = Disease.objects.update_or_create(
                label=spec['label'],
                defaults=defaults,
            )
            if was_created:
                created += 1
            else:
                updated += 1
            self.stdout.write(
                f"  {'+' if was_created else '~'} {obj.label}"
            )
        self.stdout.write(self.style.SUCCESS(
            f'Done. {created} created, {updated} updated.'
        ))
