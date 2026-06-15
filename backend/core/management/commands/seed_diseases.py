"""Seed the Disease knowledge base for the 10 tomato classes the model predicts.

Idempotent: re-running updates existing rows (keyed on `label`) rather than
duplicating. The `label` values mirror exactly the CLASS_NAMES list the ML
model outputs in core/views.py.

Data sources (consulted at authoring time, not at runtime):
  - PlantVillage — https://plantvillage.psu.edu/
  - University of Minnesota Extension — https://extension.umn.edu/diseases
  - Penn State Extension — https://extension.psu.edu/
  - Cornell Vegetable MD Online — https://www.vegetables.cornell.edu/
  - Wikipedia — general descriptions / pathogen names.

Run: python manage.py seed_diseases
(Requires the Tomato species to exist — run seed_species first.)
"""

from django.core.management.base import BaseCommand
from core.models import Disease, PlantSpecies


# One entry per CLASS_NAMES value in core/views.py. `label` is the join key.
DISEASES = [
    dict(
        label='Tomato_Bacterial_spot',
        name='Bacterial Spot',
        severity=Disease.Severity.HIGH,
        image_urls=[
            'https://upload.wikimedia.org/wikipedia/commons/e/e2/Bacterial_leaf_spot_on_pepper.jpg',
        ],
        description=(
            'A common, fast-spreading bacterial disease that attacks leaves, '
            'stems and fruit in warm, wet weather, reducing yield and making '
            'fruit unmarketable.'
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
        name='Early Blight',
        severity=Disease.Severity.MEDIUM,
        image_urls=[
            'https://upload.wikimedia.org/wikipedia/commons/0/04/Alternaria_solani_-_leaf_lesions.jpg',
        ],
        description=(
            'A widespread fungal disease that usually starts on older, lower '
            'leaves and works upward, weakening the plant and exposing fruit '
            'to sunscald.'
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
        source_url='https://extension.umn.edu/disease-management/early-blight-tomato',
    ),
    dict(
        label='Tomato_Late_blight',
        name='Late Blight',
        severity=Disease.Severity.HIGH,
        image_urls=[
            'https://upload.wikimedia.org/wikipedia/commons/a/aa/Late_blight_on_potato_leaf_2.jpg',
        ],
        description=(
            'An aggressive, destructive disease (the cause of the Irish potato '
            'famine) that can kill plants within days in cool, wet weather.'
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
        name='Leaf Mold',
        severity=Disease.Severity.MEDIUM,
        image_urls=[
            'https://upload.wikimedia.org/wikipedia/commons/5/54/TomateBlattOberseiteSamtfleckenCladosporiumfulvum.jpg',
        ],
        description=(
            'A fungal disease most common in humid greenhouses and high tunnels '
            'where air is still and moisture lingers on foliage.'
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
        name='Septoria Leaf Spot',
        severity=Disease.Severity.MEDIUM,
        image_urls=[
            'https://upload.wikimedia.org/wikipedia/commons/7/76/Septoria_lycopersici_malagutii_leaf_spot_on_tomato_leaf.jpg',
            'https://upload.wikimedia.org/wikipedia/commons/8/86/Septoria_leaf_spot_symptoms_on_tomato_leaf_%28Septoria_lycopersici_on_Solanum_lycopersicum_leaf%29.jpg',
        ],
        description=(
            'A very common leaf disease that causes heavy defoliation but does '
            'not infect the fruit directly; losses come from sunscald on '
            'exposed fruit and weakened plants.'
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
        name='Two-Spotted Spider Mites',
        severity=Disease.Severity.MEDIUM,
        image_urls=[
            'https://upload.wikimedia.org/wikipedia/commons/5/52/Tetranychus_urticae_%284883560779%29.jpg',
        ],
        description=(
            'A sap-sucking pest (not a disease) that builds up fast in hot, dry '
            'conditions and can quickly stunt or kill plants.'
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
        name='Target Spot',
        severity=Disease.Severity.MEDIUM,
        image_urls=[
            'https://upload.wikimedia.org/wikipedia/commons/2/22/Corynespora_cassiicola_Ring-Spot_Symptoms_in_Tomato_Leaves.png',
        ],
        description=(
            'A fungal disease of leaves, stems and fruit, common in warm, humid '
            'and tropical climates, that can cause significant fruit loss.'
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
        name='Tomato Yellow Leaf Curl Virus',
        severity=Disease.Severity.HIGH,
        image_urls=[
            'https://upload.wikimedia.org/wikipedia/commons/1/19/Yellow_curl_leaf_disease_Pj_IMG_3162.jpg',
        ],
        description=(
            'A serious viral disease, spread by whiteflies, that can devastate '
            'a crop, especially when plants are infected while young.'
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
        name='Tomato Mosaic Virus',
        severity=Disease.Severity.MEDIUM,
        image_urls=[
            'https://upload.wikimedia.org/wikipedia/commons/thumb/3/31/12985_2016_676_Fig4_HTML.webp/640px-12985_2016_676_Fig4_HTML.webp.png',
        ],
        description=(
            'A highly contagious and very stable virus that spreads easily by '
            'touch, on tools, and on hands, reducing vigour and fruit quality.'
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
        name='Healthy',
        severity=Disease.Severity.LOW,
        image_urls=[
            'https://upload.wikimedia.org/wikipedia/commons/8/89/Tomato_je.jpg',
        ],
        description=(
            'No disease detected. The leaf appears healthy, with normal colour '
            'and shape and no signs of spots, mould, curling or pests.'
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
]


class Command(BaseCommand):
    help = 'Seed the Disease knowledge base for the 10 tomato model classes (idempotent).'

    def handle(self, *args, **options):
        try:
            tomato = PlantSpecies.objects.get(name='Tomato')
        except PlantSpecies.DoesNotExist:
            self.stderr.write(self.style.ERROR(
                'Tomato species not found. Run `python manage.py seed_species` first.'
            ))
            return

        created = 0
        updated = 0
        for spec in DISEASES:
            label = spec.pop('label')
            obj, was_created = Disease.objects.update_or_create(
                label=label,
                defaults={**spec, 'species': tomato},
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
