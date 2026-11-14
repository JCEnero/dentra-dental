// lib/features/treatment/data/treatment_data.dart

import 'package:flutter/material.dart';
import 'models/treatment_model.dart';

/// Static list of all dental treatments shown in the Treatment screen.
abstract class TreatmentData {
  static const List<TreatmentModel> all = [
    // ── GENERAL ────────────────────────────────────────────────
    TreatmentModel(
      id: 'teeth_cleaning',
      name: 'Teeth Cleaning',
      imagePath: 'assets/images/treatments/cleaning.jpg',
      shortDescription: 'Professional cleaning to remove plaque and tartar.',
      longDescription:
          'Professional teeth cleaning (prophylaxis) is a preventive dental procedure '
          'that removes hardened plaque (tartar) and surface stains that regular brushing '
          'cannot eliminate. It is the cornerstone of good oral health and is recommended '
          'at least twice a year for most patients.',
      category: TreatmentCategory.general,
      icon: Icons.cleaning_services_rounded,
      iconPath: 'assets/images/treatments/icons/tooth_cleaning.png',
      iconColor: Color(0xFF2CA6A4),
      iconBackground: Color(0xFFE8F8F7),
      duration: '45 – 60 minutes',
      steps: [
        TreatmentStep(
          title: 'Physical Examination',
          description:
              'The dentist or hygienist examines your mouth with a small mirror to check '
              'for inflamed gums, signs of cavities, or other concerns before proceeding.',
        ),
        TreatmentStep(
          title: 'Plaque & Tartar Removal',
          description:
              'Using a scaler tool, the hygienist carefully removes tartar and plaque '
              'from around the gumline and between teeth. The more tartar present, the '
              'longer this step takes.',
        ),
        TreatmentStep(
          title: 'Gritty Toothpaste Polishing',
          description:
              'Teeth are polished with a high-powered electric brush and slightly abrasive '
              'toothpaste, removing any leftover tartar and buffing surface stains.',
        ),
        TreatmentStep(
          title: 'Expert Flossing',
          description:
              'The hygienist flosses between every tooth to remove any remaining plaque '
              'or paste, and to check for any spots that bleed easily.',
        ),
        TreatmentStep(
          title: 'Fluoride Treatment',
          description:
              'A fluoride gel or foam is applied to the teeth and left for about one '
              'minute to strengthen enamel and help fight cavities until your next visit.',
        ),
      ],
    ),

    TreatmentModel(
      id: 'tooth_filling',
      name: 'Tooth Filling',
      imagePath: 'assets/images/treatments/cleaning.jpg',
      shortDescription: 'Restore cavities with tooth-colored composite resin.',
      longDescription:
          'A dental filling repairs a tooth damaged by decay, restoring its normal shape '
          'and function while preventing further decay. Modern composite (tooth-colored) '
          'fillings bond directly to the tooth structure and are virtually invisible.',
      category: TreatmentCategory.general,
      icon: Icons.healing_rounded,
      iconPath: 'assets/images/treatments/icons/tooth_filling.png',
      iconColor: Color(0xFF4CAF93),
      iconBackground: Color(0xFFE8F5F1),
      duration: '30 – 60 minutes',
      whyRecommended:
          'To repair a tooth with a cavity: decay that has made a hole in the '
          'enamel or the layer under it. Removing the decay and sealing the '
          'tooth stops it spreading and lets you bite and chew normally '
          'again.',
      whenNeeded: [
        'Decay has made a hole (a cavity) that fluoride alone can\'t '
            'reverse.',
        'A tooth is chipped, cracked or worn, or an old filling has broken.',
        'Enough healthy tooth is left around the cavity to hold a filling.',
      ],
      aftercare: [
        'Your mouth may stay numb for a few hours. Avoid hot drinks and '
            'chewing on that side until it wears off.',
        'Some sensitivity to cold or biting is common for a few days to a '
            'couple of weeks.',
        'Tell your dentist if your bite feels high, or the tooth still '
            'hurts after a few weeks.',
        'Brush twice a day with fluoride toothpaste and clean between your '
            'teeth to protect the filling.',
      ],
      risks: [
        'Short-term sensitivity, especially after a deep filling.',
        'Fillings can wear, chip or leak over the years and may need '
            'replacing.',
        'If the decay was deep, the nerve can become inflamed later and '
            'need root canal treatment.',
        'Rarely, an allergy to a filling material.',
      ],
      steps: [
        TreatmentStep(
          title: 'Local Anaesthesia',
          description:
              'The dentist numbs the area around the affected tooth with a local '
              'anaesthetic injection so you feel no pain during the procedure.',
        ),
        TreatmentStep(
          title: 'Decay Removal',
          description:
              'A drill, air abrasion instrument, or laser is used to remove the decayed '
              'portion of the tooth, leaving only healthy tooth structure behind.',
        ),
        TreatmentStep(
          title: 'Cavity Preparation',
          description:
              'The cavity is cleaned of bacteria and debris, then etched with a mild '
              'acid gel so the composite resin bonds securely to the tooth.',
        ),
        TreatmentStep(
          title: 'Filling Placement',
          description:
              'Composite resin is applied in layers. Each layer is hardened ("cured") '
              'with a bright blue curing light before the next layer is added.',
        ),
        TreatmentStep(
          title: 'Shaping & Polishing',
          description:
              'The filling is trimmed and shaped to match your bite, then polished '
              'smooth so it looks and feels like a natural part of your tooth.',
        ),
      ],
    ),

    TreatmentModel(
      id: 'root_canal',
      name: 'Root Canal',
      imagePath: 'assets/images/treatments/cleaning.jpg',
      shortDescription: 'Treat infected tooth pulp and save the natural tooth.',
      longDescription:
          'Root canal therapy removes infected or inflamed pulp tissue from inside the '
          'tooth, cleans and shapes the root canals, then seals the space to prevent '
          'reinfection. Despite its reputation, modern root canals are no more '
          'uncomfortable than having a filling placed.',
      category: TreatmentCategory.general,
      icon: Icons.medical_services_rounded,
      iconPath: 'assets/images/treatments/icons/root_canal.png',
      iconColor: Color(0xFFE8896A),
      iconBackground: Color(0xFFFDF0EB),
      duration: '60 – 90 minutes',
      requiresFollowUp: true,
      whyRecommended:
          'To save a tooth whose nerve (the pulp) is inflamed or infected, '
          'often from deep decay, a crack or an injury. Removing the damaged '
          'pulp relieves the pain and stops the infection spreading, so the '
          'tooth can stay.',
      whenNeeded: [
        'Lasting pain, especially to hot or cold that lingers, or pain that '
            'wakes you at night.',
        'Decay or a crack has reached the pulp.',
        'An abscess or infection at the root, sometimes with a swollen gum.',
        'An X-ray and tests show the pulp can\'t heal on its own.',
      ],
      aftercare: [
        'The tooth may be tender for a few days. Pain relief from a '
            'pharmacy usually helps; follow the pack or your dentist\'s advice.',
        'Avoid chewing hard food on that tooth until the permanent filling '
            'or crown is in place.',
        'Go back for the crown or final filling, which protects the treated '
            'tooth from breaking.',
        'Contact your dentist if swelling appears, or the pain gets worse '
            'after a few days.',
      ],
      risks: [
        'A treated tooth can become brittle, which is why a crown is often '
            'advised.',
        'Sometimes infection comes back and the treatment needs redoing, or '
            'a small operation at the root tip.',
        'Rarely, a canal can\'t be fully cleaned or an instrument breaks '
            'inside it.',
        'If the tooth can\'t be saved, it may still need to come out.',
      ],
      steps: [
        TreatmentStep(
          title: 'X-Ray & Diagnosis',
          description:
              'The dentist takes an X-ray to see the shape of the root canals and '
              'determine whether there are signs of infection in the surrounding bone.',
        ),
        TreatmentStep(
          title: 'Local Anaesthesia',
          description:
              'The area around the tooth is numbed thoroughly. A rubber dam (small sheet '
              'of rubber) is placed around the tooth to keep it dry and saliva-free.',
        ),
        TreatmentStep(
          title: 'Pulp Chamber Access',
          description:
              'The dentist drills an access hole through the crown of the tooth to '
              'reach the pulp chamber and root canals.',
        ),
        TreatmentStep(
          title: 'Pulp Removal & Canal Cleaning',
          description:
              'Pulp tissue, bacteria, and debris are removed using a series of root '
              'canal files. The canals are then irrigated with sodium hypochlorite to '
              'flush away any remaining material.',
        ),
        TreatmentStep(
          title: 'Sealing & Crown Placement',
          description:
              'The cleaned canals are filled with a rubber-like material called gutta-percha '
              'and sealed with adhesive cement. A crown is typically placed at a follow-up '
              'appointment to protect and restore full function.',
        ),
      ],
    ),

    TreatmentModel(
      id: 'tooth_extraction',
      name: 'Tooth Extraction',
      imagePath: 'assets/images/treatments/cleaning.jpg',
      shortDescription: 'Safe removal of a severely damaged or impacted tooth.',
      longDescription:
          'Tooth extraction removes a tooth that cannot be saved by other treatments. '
          'Simple extractions are performed on visible teeth while surgical extractions '
          'handle teeth broken at the gumline or impacted wisdom teeth.',
      category: TreatmentCategory.general,
      icon: Icons.remove_circle_outline_rounded,
      iconPath: 'assets/images/treatments/icons/tooth_extraction.png',
      iconColor: Color(0xFFF4A261),
      iconBackground: Color(0xFFFEF4EC),
      duration: '20 – 45 minutes',
      whyRecommended:
          'To remove a tooth that can\'t be saved or is causing problems: a '
          'tooth badly broken or decayed, a severe infection, advanced gum '
          'disease, or teeth that crowd others or can\'t come through '
          'properly.',
      whenNeeded: [
        'Decay or a break has destroyed too much of the tooth to repair.',
        'Infection that a root canal can\'t treat, or a root canal that has '
            'failed.',
        'The tooth is very loose from advanced gum disease.',
        'Wisdom teeth or crowded teeth are causing pain or damage, or '
            'before braces.',
      ],
      aftercare: [
        'Bite firmly on the gauze for 30 to 45 minutes so a blood clot can '
            'form.',
        'For the first day, don\'t rinse hard, spit, smoke or drink through '
            'a straw, so the clot stays in place.',
        'Eat soft food and chew on the other side. After 24 hours, rinse '
            'gently with warm salt water.',
        'Some swelling and soreness for a few days is normal. Contact your '
            'dentist if bleeding won\'t stop, pain gets worse after 2 to 3 days, '
            'or you get a fever.',
        'Ask about replacing the tooth with an implant, bridge or denture, '
            'so the teeth around it don\'t shift.',
      ],
      risks: [
        'Dry socket: the clot comes away and the socket becomes very '
            'painful, usually 2 to 4 days later.',
        'Infection, bleeding or swelling.',
        'Rarely, for lower back teeth, numbness of the lip or tongue from '
            'an irritated nerve.',
        'Neighbouring teeth can drift into the gap if it isn\'t filled.',
      ],
      steps: [
        TreatmentStep(
          title: 'X-Ray Review',
          description:
              'The dentist reviews an X-ray of the tooth to plan the best extraction '
              'approach and assess root shape, bone density, and nearby structures.',
        ),
        TreatmentStep(
          title: 'Anaesthesia Administration',
          description:
              'Local anaesthetic is injected into the gum tissue near the tooth to '
              'completely numb the area. You will feel pressure but no sharp pain.',
        ),
        TreatmentStep(
          title: 'Tooth Loosening',
          description:
              'The dentist uses an elevator instrument to loosen the tooth within its '
              'socket by rocking it gently back and forth to widen the socket.',
        ),
        TreatmentStep(
          title: 'Extraction',
          description:
              'Dental forceps grip the tooth firmly and it is removed with controlled '
              'rocking and pulling motions. For surgical cases, a small incision in the '
              'gum may be needed first.',
        ),
        TreatmentStep(
          title: 'Gauze & Aftercare',
          description:
              'Gauze is placed over the extraction site and you bite down to help form '
              'a blood clot. Instructions for home care (diet, rinsing, medications) '
              'are provided to promote healing.',
        ),
      ],
    ),

    // ── COSMETIC ───────────────────────────────────────────────
    TreatmentModel(
      id: 'teeth_whitening',
      name: 'Teeth Whitening',
      imagePath: 'assets/images/treatments/glowing.jpg',
      shortDescription: 'Brighten your smile with safe professional whitening.',
      longDescription:
          'Professional teeth whitening uses a higher concentration of bleaching agents '
          'than over-the-counter products, achieving noticeably brighter results in a '
          'single visit. The procedure is safe, fast, and overseen by a dental professional.',
      category: TreatmentCategory.cosmetic,
      icon: Icons.auto_awesome_rounded,
      iconPath: 'assets/images/treatments/icons/teeth_whitening.png',
      iconColor: Color(0xFFF4A261),
      iconBackground: Color(0xFFFEF4EC),
      duration: '60 – 90 minutes',
      steps: [
        TreatmentStep(
          title: 'Pre-Treatment Shade Recording',
          description:
              'The dentist photographs your teeth and records the current shade using a '
              'shade guide, giving you a clear before-and-after comparison.',
        ),
        TreatmentStep(
          title: 'Gum & Soft Tissue Protection',
          description:
              'A protective barrier (rubber dam or paint-on resin) is applied to your '
              'gums and lips to shield soft tissues from the bleaching gel.',
        ),
        TreatmentStep(
          title: 'Whitening Gel Application',
          description:
              'A high-concentration hydrogen peroxide or carbamide peroxide gel is '
              'applied evenly across all visible tooth surfaces.',
        ),
        TreatmentStep(
          title: 'Light Activation',
          description:
              'A special LED or UV light is directed at the teeth to activate the '
              'bleaching gel and accelerate the whitening chemical reaction. '
              'This cycle is typically repeated 2–3 times.',
        ),
        TreatmentStep(
          title: 'Rinse & Shade Comparison',
          description:
              'The gel is rinsed off and the dentist compares your new shade to the '
              'baseline. Most patients see an improvement of 4–8 shades in a single visit.',
        ),
      ],
    ),

    TreatmentModel(
      id: 'dental_veneers',
      name: 'Dental Veneers',
      imagePath: 'assets/images/treatments/glowing.jpg',
      shortDescription:
          'Ultra-thin shells that transform the look of your smile.',
      longDescription:
          'Porcelain or composite veneers are wafer-thin shells custom-made to cover '
          'the front surface of teeth, correcting discolouration, chips, gaps, and '
          'minor misalignment in a minimally invasive way.',
      category: TreatmentCategory.cosmetic,
      icon: Icons.star_outline_rounded,
      iconPath: 'assets/images/treatments/icons/dental_veneers.png',
      iconColor: Color(0xFF2CA6A4),
      iconBackground: Color(0xFFE8F8F7),
      duration: '2 visits (1–2 hours each)',
      requiresFollowUp: true,
      steps: [
        TreatmentStep(
          title: 'Consultation & Planning',
          description:
              'The dentist discusses your smile goals, takes impressions or digital '
              'scans, and designs the shape and shade of your veneers together with you.',
        ),
        TreatmentStep(
          title: 'Enamel Preparation',
          description:
              'A thin layer of enamel (about 0.3–0.5 mm) is removed from each tooth '
              'to create space for the veneer so your smile looks natural, not bulky.',
        ),
        TreatmentStep(
          title: 'Impressions & Temporaries',
          description:
              'Impressions are sent to the lab. Temporary veneers protect your teeth '
              'while your permanent veneers are custom-crafted (usually 1–2 weeks).',
        ),
        TreatmentStep(
          title: 'Veneer Bonding',
          description:
              'At the second visit, temporaries are removed and each veneer is checked '
              'for fit and colour. The tooth surface is etched and the veneer is bonded '
              'permanently with special dental cement, then light-cured.',
        ),
        TreatmentStep(
          title: 'Final Adjustments',
          description:
              'The dentist trims any excess cement, checks your bite, and polishes '
              'the veneers to a natural sheen. A follow-up in a few weeks confirms '
              'your gums have responded well.',
        ),
      ],
    ),

    // ── ORTHODONTICS ───────────────────────────────────────────
    TreatmentModel(
      id: 'orthodontics',
      name: 'Orthodontics',
      imagePath: 'assets/images/treatments/braces.jpg',
      shortDescription: 'Braces and aligners for a straighter, perfect smile.',
      longDescription:
          'Orthodontic treatment straightens teeth and corrects bite issues using '
          'fixed braces or removable clear aligners. Treatment not only improves '
          'aesthetics but also makes teeth easier to clean and reduces jaw strain.',
      category: TreatmentCategory.orthodontics,
      icon: Icons.grid_3x3_rounded,
      iconPath: 'assets/images/treatments/icons/orthodontics.png',
      iconColor: Color(0xFF2CA6A4),
      iconBackground: Color(0xFFE8F8F7),
      duration: '12 – 36 months',
      requiresFollowUp: true,
      steps: [
        TreatmentStep(
          title: 'Comprehensive Examination',
          description:
              'The orthodontist takes X-rays, photographs, and digital scans to map '
              'your teeth, roots, jaw, and facial structure in full 3D detail.',
        ),
        TreatmentStep(
          title: 'Custom Treatment Plan',
          description:
              'Using the diagnostic records, the orthodontist designs a personalised '
              'plan showing the projected tooth movements and estimated treatment duration.',
        ),
        TreatmentStep(
          title: 'Appliance Placement',
          description:
              'For braces, brackets are bonded to each tooth and connected with an '
              'archwire. For clear aligners, a series of custom trays is provided; '
              'you wear each tray for about two weeks before advancing to the next.',
        ),
        TreatmentStep(
          title: 'Regular Adjustment Visits',
          description:
              'Every 4–8 weeks the orthodontist checks progress, adjusts wires or '
              'provides the next set of aligners, and monitors gum and tooth health.',
        ),
        TreatmentStep(
          title: 'Retention Phase',
          description:
              'After braces or aligners are finished, retainers (fixed or removable) '
              'are fitted to hold teeth in their new positions while bone remodels '
              'around the roots.',
        ),
      ],
    ),

    TreatmentModel(
      id: 'clear_aligners',
      name: 'Clear Aligners',
      imagePath: 'assets/images/treatments/braces.jpg',
      shortDescription:
          'Nearly invisible trays that gradually straighten teeth.',
      longDescription:
          'Clear aligner therapy uses a series of custom, removable plastic trays to '
          'move teeth incrementally. Each tray is slightly different, gently guiding '
          'teeth toward the target position over several months.',
      category: TreatmentCategory.orthodontics,
      icon: Icons.visibility_off_rounded,
      iconPath: 'assets/images/treatments/icons/clear_aligners.png',
      iconColor: Color(0xFF4DD8C8),
      iconBackground: Color(0xFFEBFAF9),
      duration: '6 – 18 months',
      requiresFollowUp: true,
      steps: [
        TreatmentStep(
          title: 'Digital Scan & 3D Modelling',
          description:
              'An intraoral scanner captures a precise 3D model of your teeth. '
              'Software simulates the full tooth-movement journey from start to finish.',
        ),
        TreatmentStep(
          title: 'Attachment Placement',
          description:
              'Small tooth-coloured composite "buttons" called attachments may be '
              'bonded to certain teeth. They give the aligner trays something to '
              'grip for more controlled movements.',
        ),
        TreatmentStep(
          title: 'Tray Progression',
          description:
              'You wear each set of trays for 20–22 hours per day for approximately '
              'two weeks, then switch to the next set. Trays are removed only to eat, '
              'drink anything other than water, and to brush and floss.',
        ),
        TreatmentStep(
          title: 'Progress Check Visits',
          description:
              'Every 6–8 weeks the orthodontist checks that your teeth are tracking '
              'correctly, makes any necessary adjustments, and issues the next batch '
              'of trays.',
        ),
        TreatmentStep(
          title: 'Refinements & Retainers',
          description:
              'If teeth need minor fine-tuning after the initial series, refinement '
              'trays are made. A final clear retainer is provided to maintain results '
              'long term.',
        ),
      ],
    ),

    // ── SURGICAL ───────────────────────────────────────────────
    TreatmentModel(
      id: 'dental_implants',
      name: 'Dental Implants',
      imagePath: 'assets/images/treatments/implants.jpg',
      shortDescription: 'Permanent titanium roots for replacing missing teeth.',
      longDescription:
          'Dental implants are titanium posts surgically placed into the jawbone to '
          'act as artificial tooth roots. They provide a stable, long-lasting foundation '
          'for replacement teeth that look, feel, and function exactly like natural ones.',
      category: TreatmentCategory.surgical,
      icon: Icons.hardware_rounded,
      iconPath: 'assets/images/treatments/icons/dental_implants.png',
      iconColor: Color(0xFF6B7B80),
      iconBackground: Color(0xFFF0F3F4),
      duration: '3 – 6 months (full process)',
      requiresFollowUp: true,
      steps: [
        TreatmentStep(
          title: 'Evaluation & Bone Assessment',
          description:
              'A 3D cone-beam CT scan evaluates bone density and volume at the implant '
              'site. If insufficient bone is present, a bone graft may be recommended first.',
        ),
        TreatmentStep(
          title: 'Implant Placement Surgery',
          description:
              'Under local anaesthesia (or sedation), the oral surgeon makes a small '
              'incision in the gum and drills a precise channel in the jawbone. The '
              'titanium implant post is inserted and the gum is stitched closed.',
        ),
        TreatmentStep(
          title: 'Osseointegration',
          description:
              'Over 3–6 months the implant fuses with the surrounding jawbone in a '
              'process called osseointegration, creating a rock-solid anchor for the '
              'replacement tooth.',
        ),
        TreatmentStep(
          title: 'Abutment Placement',
          description:
              'Once fully healed, a small connector piece called an abutment is attached '
              'to the implant post. It protrudes through the gum and will support the '
              'final crown.',
        ),
        TreatmentStep(
          title: 'Crown Fitting',
          description:
              'A custom-made porcelain crown — matched to the colour of your natural '
              'teeth — is secured onto the abutment, completing your new tooth.',
        ),
      ],
    ),

    TreatmentModel(
      id: 'wisdom_tooth_removal',
      name: 'Wisdom Tooth Removal',
      imagePath: 'assets/images/treatments/implants.jpg',
      shortDescription:
          'Surgical extraction of impacted or problematic wisdom teeth.',
      longDescription:
          'Wisdom teeth (third molars) often emerge at an angle or become trapped '
          '(impacted) in the jawbone, causing pain, crowding, and infection risk. '
          'Surgical removal prevents these complications and relieves discomfort.',
      category: TreatmentCategory.surgical,
      icon: Icons.cut_rounded,
      iconPath: 'assets/images/treatments/icons/wisdom_tooth_removal.png',
      iconColor: Color(0xFFE8896A),
      iconBackground: Color(0xFFFDF0EB),
      duration: '45 – 90 minutes',
      requiresFollowUp: true,
      steps: [
        TreatmentStep(
          title: 'X-Ray & Treatment Planning',
          description:
              'A panoramic X-ray reveals the exact position, angle, and depth of all '
              'four wisdom teeth so the surgeon can plan the safest removal approach.',
        ),
        TreatmentStep(
          title: 'Anaesthesia',
          description:
              'Local anaesthesia numbs the area. Sedation (nitrous oxide, oral sedative, '
              'or IV) may be offered for patients who prefer to be more relaxed or '
              'who have multiple teeth removed at once.',
        ),
        TreatmentStep(
          title: 'Incision & Bone Access',
          description:
              'The surgeon makes an incision in the gum and, if the tooth is impacted, '
              'removes a small amount of bone covering the tooth to access it fully.',
        ),
        TreatmentStep(
          title: 'Tooth Sectioning & Removal',
          description:
              'Impacted teeth are often divided into smaller sections so they can be '
              'removed with minimal disturbance to surrounding bone and tissue.',
        ),
        TreatmentStep(
          title: 'Stitching & Recovery',
          description:
              'The surgical site is cleaned and stitched closed. Gauze is placed to '
              'control bleeding. Detailed aftercare instructions — including diet, '
              'medications, and when to call the dentist — are provided.',
        ),
      ],
    ),

    // ── GENERAL (continued) ────────────────────────────────────
    TreatmentModel(
      id: 'dental_crown',
      name: 'Dental Crown',
      imagePath: 'assets/images/treatments/cleaning.jpg',
      shortDescription:
          'A cap that fully restores a damaged or weakened tooth.',
      longDescription:
          'A dental crown is a tooth-shaped cap placed over a damaged, decayed, or '
          'weakened tooth to restore its shape, size, strength, and appearance. '
          'Crowns can be made from porcelain, ceramic, metal alloy, or a combination, '
          'and are custom-fabricated to blend seamlessly with surrounding teeth.',
      category: TreatmentCategory.general,
      icon: Icons.circle_outlined,
      iconPath: 'assets/images/treatments/icons/dental_crown.png',
      iconColor: Color(0xFF2CA6A4),
      iconBackground: Color(0xFFE8F8F7),
      duration: '2 visits (1 hour each)',
      requiresFollowUp: true,
      whyRecommended:
          'To cover and protect a tooth that is too damaged or weak for a '
          'filling alone: after large decay, a crack, or root canal '
          'treatment.',
      whenNeeded: [
        'A cavity or old filling is too big for the tooth to hold a filling '
            'well.',
        'A tooth is cracked or badly worn.',
        'After root canal treatment, especially on back teeth.',
        'To cover a dental implant or hold a bridge.',
      ],
      aftercare: [
        'With a temporary crown, avoid sticky or hard food and chew on the '
            'other side.',
        'Some sensitivity for a few days is common once the permanent crown '
            'is fitted.',
        'Brush and clean between your teeth as normal, especially where the '
            'crown meets the gum.',
        'Tell your dentist if the crown feels high or loose.',
      ],
      risks: [
        'The tooth underneath can still decay at the edge of the crown.',
        'Crowns can chip, loosen or come off, and may need replacing after '
            'years of use.',
        'Shaping the tooth can sometimes inflame the nerve, which then '
            'needs root canal treatment.',
        'Some sensitivity, or a darker line at the gum with metal-based '
            'crowns.',
      ],
      steps: [
        TreatmentStep(
          title: 'Tooth Preparation',
          description:
              'The dentist reshapes the tooth by filing down the outer layer to make '
              'room for the crown. If the tooth is severely damaged, a filling may be '
              'used to build it up first.',
        ),
        TreatmentStep(
          title: 'Impression Taking',
          description:
              'A digital scan or putty impression captures the exact shape of your '
              'prepared tooth and the surrounding teeth so the crown fits perfectly.',
        ),
        TreatmentStep(
          title: 'Temporary Crown',
          description:
              'A temporary acrylic crown is placed to protect the prepared tooth '
              'while the permanent crown is custom-fabricated in a dental laboratory.',
        ),
        TreatmentStep(
          title: 'Permanent Crown Fitting',
          description:
              'At the second visit the temporary crown is removed, the fit and colour '
              'of the permanent crown are checked, and it is cemented firmly into place.',
        ),
        TreatmentStep(
          title: 'Bite Adjustment',
          description:
              'The dentist checks your bite and makes minor adjustments to ensure the '
              'crown feels comfortable and does not interfere with surrounding teeth.',
        ),
      ],
    ),

    TreatmentModel(
      id: 'dental_bridge',
      name: 'Dental Bridge',
      imagePath: 'assets/images/treatments/cleaning.jpg',
      shortDescription:
          'Replace one or more missing teeth with a fixed bridge.',
      longDescription:
          'A dental bridge literally bridges the gap left by one or more missing teeth. '
          'It consists of two or more crowns on the teeth either side of the gap (abutment '
          'teeth) and a false tooth (pontic) in between, all fused together into a single '
          'fixed restoration.',
      category: TreatmentCategory.general,
      icon: Icons.linear_scale_rounded,
      iconPath: 'assets/images/treatments/icons/dental_bridge.png',
      iconColor: Color(0xFF4CAF93),
      iconBackground: Color(0xFFE8F5F1),
      duration: '2 visits (1–2 hours each)',
      requiresFollowUp: true,
      steps: [
        TreatmentStep(
          title: 'Abutment Preparation',
          description:
              'The teeth on either side of the gap are reshaped under local anaesthesia '
              'to accommodate the crowns that will anchor the bridge.',
        ),
        TreatmentStep(
          title: 'Impressions',
          description:
              'Detailed impressions of the prepared teeth and the gap are taken and sent '
              'to the lab to fabricate a perfectly fitting bridge.',
        ),
        TreatmentStep(
          title: 'Temporary Bridge',
          description:
              'A temporary bridge protects the exposed teeth and maintains aesthetics '
              'while the permanent bridge is being made (usually 2 weeks).',
        ),
        TreatmentStep(
          title: 'Bridge Placement',
          description:
              'The permanent bridge is tried in for fit and appearance, then cemented '
              'onto the abutment teeth with strong dental adhesive.',
        ),
        TreatmentStep(
          title: 'Aftercare Guidance',
          description:
              'The dentist demonstrates how to clean under the pontic with floss '
              'threaders or interdental brushes to prevent decay and gum disease.',
        ),
      ],
    ),

    TreatmentModel(
      id: 'night_guard',
      name: 'Night Guard',
      imagePath: 'assets/images/treatments/cleaning.jpg',
      shortDescription: 'Custom mouthguard to protect teeth from grinding.',
      longDescription:
          'Bruxism (teeth grinding) during sleep can wear down enamel, cause jaw pain, '
          'and lead to cracked teeth. A custom-fitted night guard creates a protective '
          'barrier between upper and lower teeth, absorbing grinding forces and '
          'preventing long-term damage.',
      category: TreatmentCategory.general,
      icon: Icons.shield_outlined,
      iconPath: 'assets/images/treatments/icons/night_guard.png',
      iconColor: Color(0xFFF4A261),
      iconBackground: Color(0xFFFEF4EC),
      duration: '2 visits (30 minutes each)',
      requiresFollowUp: true,
      steps: [
        TreatmentStep(
          title: 'Assessment',
          description:
              'The dentist examines your teeth for signs of wear, checks your jaw '
              'muscles for tension, and confirms a bruxism diagnosis.',
        ),
        TreatmentStep(
          title: 'Impressions',
          description:
              'Upper and lower impressions are taken to create a stone model of your '
              'teeth that the lab uses to fabricate your custom guard.',
        ),
        TreatmentStep(
          title: 'Guard Fabrication',
          description:
              'A hard or soft acrylic guard (depending on grind severity) is made in '
              'the lab and usually ready within one to two weeks.',
        ),
        TreatmentStep(
          title: 'Fitting & Adjustment',
          description:
              'The guard is seated and adjusted for comfort and correct bite. '
              'It should feel secure but not cause pressure on any individual tooth.',
        ),
        TreatmentStep(
          title: 'Care Instructions',
          description:
              'You are shown how to clean the guard daily with a soft brush and '
              'cool water, and advised on storage to maintain its shape and hygiene.',
        ),
      ],
    ),

    TreatmentModel(
      id: 'fluoride_treatment',
      name: 'Fluoride Treatment',
      imagePath: 'assets/images/treatments/cleaning.jpg',
      shortDescription: 'Strengthen enamel and prevent cavities with fluoride.',
      longDescription:
          'Professional fluoride treatments deliver a high concentration of fluoride '
          'directly to the tooth surface, remineralising weakened enamel and making '
          'teeth more resistant to acid attacks from bacteria and dietary sugars. '
          'Recommended for children, patients prone to cavities, and those with dry mouth.',
      category: TreatmentCategory.general,
      icon: Icons.water_drop_rounded,
      iconPath: 'assets/images/treatments/icons/fluoride_treatment.png',
      iconColor: Color(0xFF2CA6A4),
      iconBackground: Color(0xFFE8F8F7),
      duration: '15 – 30 minutes',
      whyRecommended:
          'To strengthen enamel and help stop early decay. Fluoride helps '
          'weakened enamel take back minerals, so very early decay that '
          'hasn\'t made a hole can sometimes be stopped or reversed.',
      whenNeeded: [
        'Early decay, such as chalky white spots, before a cavity forms.',
        'A higher risk of decay: frequent cavities, dry mouth, braces, or '
            'gums that have pulled back.',
        'Children\'s teeth, which dentists often protect with fluoride '
            'varnish.',
        'Sensitive teeth, which fluoride can help settle.',
      ],
      aftercare: [
        'Don\'t eat, drink or rinse for at least 30 minutes, or as long as '
            'your dentist says.',
        'After varnish, skip hot drinks, hard or sticky food and brushing '
            'until the next morning, if you\'re told to.',
        'Keep brushing twice a day with fluoride toothpaste, and cut down '
            'on sugary food and drinks.',
      ],
      risks: [
        'Very safe in the amounts dentists use.',
        'Teeth can look slightly yellow or dull until the varnish brushes '
            'off the next day.',
        'Swallowing gel can upset the stomach, which is why only a little '
            'is used.',
        'It helps early decay, but a cavity that has already formed still '
            'needs a filling.',
      ],
      steps: [
        TreatmentStep(
          title: 'Teeth Cleaning',
          description:
              'Teeth are polished clean first so the fluoride can make direct contact '
              'with the enamel surface without interference from plaque or debris.',
        ),
        TreatmentStep(
          title: 'Fluoride Application',
          description:
              'A high-concentration fluoride varnish, gel, or foam is applied to all '
              'tooth surfaces using a tray, brush, or painted on directly.',
        ),
        TreatmentStep(
          title: 'Setting Time',
          description:
              'The fluoride is left on the teeth for a set period (varnish sets almost '
              'immediately; gel trays are worn for about four minutes).',
        ),
        TreatmentStep(
          title: 'Post-Treatment Instructions',
          description:
              'You are advised not to eat, drink, or rinse for at least 30 minutes '
              'to allow the fluoride to fully absorb into the enamel.',
        ),
      ],
    ),

    // ── COSMETIC (continued) ───────────────────────────────────
    TreatmentModel(
      id: 'dental_bonding',
      name: 'Dental Bonding',
      imagePath: 'assets/images/treatments/glowing.jpg',
      shortDescription: 'Repair chips and gaps with tooth-coloured resin.',
      longDescription:
          'Dental bonding applies a tooth-coloured composite resin to repair chipped, '
          'cracked, or discoloured teeth, or to close small gaps between teeth. It is '
          'one of the quickest and most affordable cosmetic dental procedures, requiring '
          'little to no enamel removal.',
      category: TreatmentCategory.cosmetic,
      icon: Icons.brush_rounded,
      iconPath: 'assets/images/treatments/icons/dental_bonding.png',
      iconColor: Color(0xFFF4A261),
      iconBackground: Color(0xFFFEF4EC),
      duration: '30 – 60 minutes per tooth',
      steps: [
        TreatmentStep(
          title: 'Shade Selection',
          description:
              'The dentist uses a shade guide to select a composite resin colour that '
              'closely matches your natural tooth colour.',
        ),
        TreatmentStep(
          title: 'Surface Preparation',
          description:
              'The tooth surface is lightly roughened and coated with a conditioning '
              'liquid to help the bonding material adhere securely.',
        ),
        TreatmentStep(
          title: 'Resin Application',
          description:
              'The putty-like resin is applied, moulded, and smoothed to achieve '
              'the desired shape, filling the chip or gap naturally.',
        ),
        TreatmentStep(
          title: 'Curing',
          description:
              'A bright UV or LED light hardens the resin in seconds, bonding it '
              'permanently to the tooth structure.',
        ),
        TreatmentStep(
          title: 'Finishing & Polishing',
          description:
              'The bonded area is trimmed, shaped to match your bite, and polished '
              'until it blends seamlessly with the surrounding tooth.',
        ),
      ],
    ),

    TreatmentModel(
      id: 'gum_contouring',
      name: 'Gum Contouring',
      imagePath: 'assets/images/treatments/glowing.jpg',
      shortDescription: 'Reshape the gumline for a more balanced, even smile.',
      longDescription:
          'Gum contouring (gingivoplasty) removes or reshapes excess gum tissue to '
          'correct a "gummy smile" or uneven gumline. Using a soft-tissue laser or '
          'scalpel, the procedure exposes more of the tooth crown for a symmetrical, '
          'aesthetically pleasing result.',
      category: TreatmentCategory.cosmetic,
      icon: Icons.format_align_center_rounded,
      iconPath: 'assets/images/treatments/icons/gum_contouring.png',
      iconColor: Color(0xFF2CA6A4),
      iconBackground: Color(0xFFE8F8F7),
      duration: '1 – 2 hours',
      steps: [
        TreatmentStep(
          title: 'Consultation & Smile Design',
          description:
              'The dentist maps out the new gumline with a pen or digital design tool, '
              'showing you a preview of the anticipated result before any tissue is removed.',
        ),
        TreatmentStep(
          title: 'Local Anaesthesia',
          description:
              'The gum tissue is numbed thoroughly with local anaesthetic so the '
              'procedure is completely comfortable.',
        ),
        TreatmentStep(
          title: 'Tissue Removal',
          description:
              'A soft-tissue laser or scalpel carefully removes excess gum tissue '
              'along the planned contour line, exposing more of each tooth crown.',
        ),
        TreatmentStep(
          title: 'Reshaping & Sculpting',
          description:
              'The gumline is sculpted to create smooth curves and symmetry across '
              'all visible teeth, taking care to preserve healthy tissue.',
        ),
        TreatmentStep(
          title: 'Healing & Aftercare',
          description:
              'The gums heal over 1–2 weeks. You will be advised to eat soft foods, '
              'rinse with a prescribed mouthwash, and avoid strenuous activity initially.',
        ),
      ],
    ),

    TreatmentModel(
      id: 'smile_makeover',
      name: 'Smile Makeover',
      imagePath: 'assets/images/treatments/glowing.jpg',
      shortDescription: 'A personalised combination of cosmetic treatments.',
      longDescription:
          'A smile makeover combines two or more cosmetic dental procedures — such as '
          'whitening, veneers, bonding, and gum contouring — into a single customised '
          'treatment plan designed to address all of a patient\'s aesthetic concerns '
          'and deliver a complete smile transformation.',
      category: TreatmentCategory.cosmetic,
      icon: Icons.auto_fix_high_rounded,
      iconPath: 'assets/images/treatments/icons/smile_makeover.png',
      iconColor: Color(0xFFF4A261),
      iconBackground: Color(0xFFFEF4EC),
      duration: 'Varies (multiple visits)',
      requiresFollowUp: true,
      steps: [
        TreatmentStep(
          title: 'Comprehensive Smile Analysis',
          description:
              'The dentist evaluates facial proportions, tooth shape, colour, alignment, '
              'and gum health to identify everything contributing to smile concerns.',
        ),
        TreatmentStep(
          title: 'Digital Smile Design',
          description:
              'Using photos and digital software, the dentist visualises the end result '
              'so you can approve the planned look before treatment begins.',
        ),
        TreatmentStep(
          title: 'Treatment Sequencing',
          description:
              'Procedures are scheduled in the correct order — for example, orthodontics '
              'first, then whitening, then veneers — to ensure each step complements '
              'the next.',
        ),
        TreatmentStep(
          title: 'Individual Procedures',
          description:
              'Each component treatment is carried out according to its own protocol, '
              'with the overall plan guiding every decision on shade, shape, and position.',
        ),
        TreatmentStep(
          title: 'Final Review',
          description:
              'Once all procedures are complete, the dentist reviews the full result '
              'with you, makes any fine adjustments, and provides a long-term '
              'maintenance plan.',
        ),
      ],
    ),

    // ── ORTHODONTICS (continued) ───────────────────────────────
    TreatmentModel(
      id: 'retainers',
      name: 'Retainers',
      imagePath: 'assets/images/treatments/braces.jpg',
      shortDescription: 'Keep teeth in position after orthodontic treatment.',
      longDescription:
          'Retainers are custom appliances worn after braces or aligner therapy to '
          'hold teeth in their corrected positions while the surrounding bone stabilises. '
          'They can be removable (clear or Hawley wire) or fixed (bonded behind the teeth).',
      category: TreatmentCategory.orthodontics,
      icon: Icons.lock_outline_rounded,
      iconPath: 'assets/images/treatments/icons/retainers.png',
      iconColor: Color(0xFF2CA6A4),
      iconBackground: Color(0xFFE8F8F7),
      duration: '1 visit (30 minutes)',
      steps: [
        TreatmentStep(
          title: 'Post-Treatment Scan',
          description:
              'Once active orthodontic treatment ends, a final digital scan or '
              'impression is taken of your newly aligned teeth.',
        ),
        TreatmentStep(
          title: 'Retainer Fabrication',
          description:
              'Your retainer — clear vacuum-formed, Hawley wire, or fixed lingual wire — '
              'is custom-made from the final scan and typically ready within a week.',
        ),
        TreatmentStep(
          title: 'Fitting',
          description:
              'The retainer is seated and checked for fit, comfort, and correct '
              'coverage of all teeth. Adjustments are made if needed.',
        ),
        TreatmentStep(
          title: 'Wear Schedule',
          description:
              'You are advised to wear the retainer full-time initially (except when '
              'eating and brushing), gradually reducing to nights-only after a few months.',
        ),
        TreatmentStep(
          title: 'Ongoing Monitoring',
          description:
              'Periodic check-ups confirm the retainer is still fitting well and teeth '
              'have not shifted. Worn or broken retainers should be replaced promptly.',
        ),
      ],
    ),

    TreatmentModel(
      id: 'space_maintainer',
      name: 'Space Maintainer',
      imagePath: 'assets/images/treatments/braces.jpg',
      shortDescription: 'Hold space open after early tooth loss in children.',
      longDescription:
          'When a baby tooth is lost prematurely, neighbouring teeth can drift into '
          'the empty space, blocking the permanent tooth from erupting correctly. '
          'A space maintainer is a small fixed or removable appliance that holds the '
          'gap open until the permanent tooth is ready to come through.',
      category: TreatmentCategory.orthodontics,
      icon: Icons.space_bar_rounded,
      iconPath: 'assets/images/treatments/icons/space_maintainer.png',
      iconColor: Color(0xFF4DD8C8),
      iconBackground: Color(0xFFEBFAF9),
      duration: '1 visit (45 minutes)',
      steps: [
        TreatmentStep(
          title: 'Assessment',
          description:
              'The dentist takes an X-ray to check the development stage of the '
              'permanent tooth beneath the gap and confirms a maintainer is needed.',
        ),
        TreatmentStep(
          title: 'Impression or Scan',
          description:
              'An impression or digital scan is taken of the affected area so the '
              'appliance can be custom-made for a precise fit.',
        ),
        TreatmentStep(
          title: 'Appliance Placement',
          description:
              'The space maintainer — usually a band-and-loop or distal shoe — is '
              'cemented onto the adjacent tooth to hold the gap open.',
        ),
        TreatmentStep(
          title: 'Monitoring',
          description:
              'Regular check-ups track the eruption of the permanent tooth. '
              'The maintainer is removed as soon as the permanent tooth starts emerging.',
        ),
      ],
    ),

    TreatmentModel(
      id: 'jaw_expander',
      name: 'Jaw Expander',
      imagePath: 'assets/images/treatments/braces.jpg',
      shortDescription:
          'Widen the upper jaw to correct crowding and crossbite.',
      longDescription:
          'A palatal expander applies gentle outward pressure to the two halves of '
          'the upper jaw (palate), gradually widening it to create more space for '
          'permanent teeth and correct crossbites. It is most effective in children '
          'and adolescents whose palatal suture has not yet fully fused.',
      category: TreatmentCategory.orthodontics,
      icon: Icons.open_with_rounded,
      iconPath: 'assets/images/treatments/icons/jaw_expander.png',
      iconColor: Color(0xFF2CA6A4),
      iconBackground: Color(0xFFE8F8F7),
      duration: '3 – 6 months',
      requiresFollowUp: true,
      steps: [
        TreatmentStep(
          title: 'Orthodontic Evaluation',
          description:
              'X-rays and dental models confirm the degree of crowding or crossbite '
              'and whether expansion is the appropriate treatment approach.',
        ),
        TreatmentStep(
          title: 'Expander Fitting',
          description:
              'The custom expander is cemented to the upper molars. The parent or '
              'patient is taught how to use the small key to activate it each day.',
        ),
        TreatmentStep(
          title: 'Active Expansion Phase',
          description:
              'The key is turned daily or every other day as prescribed, applying '
              'gentle force that gradually separates the palatal suture over weeks.',
        ),
        TreatmentStep(
          title: 'Retention Phase',
          description:
              'Once the target width is reached, the expander remains in place for '
              'several months without further turning, allowing bone to fill in the '
              'expanded suture.',
        ),
        TreatmentStep(
          title: 'Removal & Follow-up',
          description:
              'The expander is removed and a retainer or braces may follow to '
              'maintain the new arch width and complete alignment treatment.',
        ),
      ],
    ),

    // ── SURGICAL (continued) ───────────────────────────────────
    TreatmentModel(
      id: 'bone_grafting',
      name: 'Bone Grafting',
      imagePath: 'assets/images/treatments/implants.jpg',
      shortDescription: 'Rebuild jawbone volume to support dental implants.',
      longDescription:
          'Bone grafting adds bone or bone-like material to areas of the jaw where '
          'volume has been lost due to tooth extraction, gum disease, or trauma. '
          'It is often a prerequisite for dental implant placement when insufficient '
          'bone is present to anchor the implant securely.',
      category: TreatmentCategory.surgical,
      icon: Icons.architecture_rounded,
      iconPath: 'assets/images/treatments/icons/bone_grafting.png',
      iconColor: Color(0xFF6B7B80),
      iconBackground: Color(0xFFF0F3F4),
      duration: '45 – 90 minutes',
      requiresFollowUp: true,
      steps: [
        TreatmentStep(
          title: 'Imaging & Planning',
          description:
              'A cone-beam CT scan measures the bone defect precisely, helping the '
              'surgeon plan the graft size, material type, and surgical approach.',
        ),
        TreatmentStep(
          title: 'Anaesthesia',
          description:
              'Local anaesthesia (with or without sedation) is administered to ensure '
              'a comfortable, pain-free procedure.',
        ),
        TreatmentStep(
          title: 'Graft Placement',
          description:
              'The surgeon opens the gum tissue at the defect site and places the '
              'graft material — autograft (own bone), allograft, xenograft, or synthetic '
              '— into the area, filling and reinforcing the deficiency.',
        ),
        TreatmentStep(
          title: 'Membrane Covering',
          description:
              'A resorbable or non-resorbable membrane is often placed over the graft '
              'to protect it and guide new bone growth.',
        ),
        TreatmentStep(
          title: 'Healing Period',
          description:
              'The graft integrates with existing bone over 3–6 months. Implant '
              'placement is planned once sufficient density and volume are confirmed '
              'on a follow-up CT scan.',
        ),
      ],
    ),

    TreatmentModel(
      id: 'sinus_lift',
      name: 'Sinus Lift',
      imagePath: 'assets/images/treatments/implants.jpg',
      shortDescription: 'Add bone beneath the sinus to enable upper implants.',
      longDescription:
          'A sinus lift (sinus augmentation) adds bone to the upper jaw in the area '
          'of the molars and premolars, between the jaw and the maxillary sinuses. '
          'It is performed when the sinus is too close to the jaw to place a dental '
          'implant without risking sinus perforation.',
      category: TreatmentCategory.surgical,
      icon: Icons.vertical_align_top_rounded,
      iconPath: 'assets/images/treatments/icons/sinus_lift.png',
      iconColor: Color(0xFFE8896A),
      iconBackground: Color(0xFFFDF0EB),
      duration: '1.5 – 2 hours',
      requiresFollowUp: true,
      steps: [
        TreatmentStep(
          title: 'Pre-Surgical Imaging',
          description:
              'CT scans measure the height of existing bone and the anatomy of the '
              'sinus to plan the precise volume of graft material needed.',
        ),
        TreatmentStep(
          title: 'Anaesthesia & Access',
          description:
              'Under local anaesthesia or sedation, the surgeon makes an incision in '
              'the gum and creates a small window in the lateral sinus wall.',
        ),
        TreatmentStep(
          title: 'Sinus Membrane Elevation',
          description:
              'The sinus membrane is carefully lifted upward and the space beneath it '
              'is filled with bone graft material.',
        ),
        TreatmentStep(
          title: 'Wound Closure',
          description:
              'The incision is sutured closed. The graft material is left to integrate '
              'with the surrounding bone over the healing period.',
        ),
        TreatmentStep(
          title: 'Healing & Implant Placement',
          description:
              'After 4–9 months of healing, a follow-up CT scan confirms adequate bone '
              'volume, and dental implant placement proceeds as planned.',
        ),
      ],
    ),

    TreatmentModel(
      id: 'frenectomy',
      name: 'Frenectomy',
      imagePath: 'assets/images/treatments/implants.jpg',
      shortDescription:
          'Remove restrictive tissue causing tongue-tie or lip-tie.',
      longDescription:
          'A frenectomy removes or modifies the frenum — a small fold of tissue that '
          'connects the lip or tongue to the gum or floor of the mouth. When this '
          'tissue is too tight (tongue-tie or lip-tie), it can restrict movement, '
          'affect speech, feeding, and orthodontic outcomes. A laser frenectomy is '
          'quick, precise, and virtually bloodless.',
      category: TreatmentCategory.surgical,
      icon: Icons.content_cut_rounded,
      iconPath: 'assets/images/treatments/icons/frenectomy.png',
      iconColor: Color(0xFF6B7B80),
      iconBackground: Color(0xFFF0F3F4),
      duration: '15 – 30 minutes',
      steps: [
        TreatmentStep(
          title: 'Diagnosis',
          description:
              'The dentist or oral surgeon evaluates the frenum attachment and its '
              'functional impact on tongue movement, speech, or the gap between teeth.',
        ),
        TreatmentStep(
          title: 'Anaesthesia',
          description:
              'A topical anaesthetic is applied first, followed by a small injection '
              'of local anaesthetic to numb the area completely.',
        ),
        TreatmentStep(
          title: 'Frenum Release',
          description:
              'A soft-tissue laser or surgical scissors cuts and releases the frenum, '
              'freeing the tongue or lip from restriction. The laser simultaneously '
              'seals blood vessels, minimising bleeding.',
        ),
        TreatmentStep(
          title: 'Suturing (if needed)',
          description:
              'Laser frenectomies usually require no stitches. Scalpel procedures may '
              'need one or two dissolving sutures to close the site.',
        ),
        TreatmentStep(
          title: 'Recovery & Exercises',
          description:
              'Healing is rapid — typically 1–2 weeks. Stretching exercises are '
              'prescribed to prevent reattachment and maximise freedom of movement.',
        ),
      ],
    ),
  ];

  /// The treatment with [id], or null if there's none.
  static TreatmentModel? byId(String id) {
    for (final t in all) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Returns treatments filtered by [category], or all treatments if null.
  static List<TreatmentModel> byCategory(TreatmentCategory? category) {
    if (category == null) return all;
    return all.where((t) => t.category == category).toList();
  }

  /// Returns treatments whose name or description contains [query] (case-insensitive).
  static List<TreatmentModel> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where(
          (t) =>
              t.name.toLowerCase().contains(q) ||
              t.shortDescription.toLowerCase().contains(q),
        )
        .toList();
  }
}
