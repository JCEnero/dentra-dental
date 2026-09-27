// lib/features/treatment/data/treatment_data.dart

import 'package:flutter/material.dart';
import 'models/treatment_model.dart';
import '../../../core/constants/app_colors.dart';

/// Static list of all dental treatments shown in the Treatment screen.
abstract class TreatmentData {
  static const List<TreatmentModel> all = [
    // ── GENERAL ────────────────────────────────────────────────
    TreatmentModel(
      id: 'teeth_cleaning',
      name: 'Teeth Cleaning',
      shortDescription: 'Professional cleaning to remove plaque and tartar.',
      longDescription:
          'Professional teeth cleaning (prophylaxis) is a preventive dental procedure '
          'that removes hardened plaque (tartar) and surface stains that regular brushing '
          'cannot eliminate. It is the cornerstone of good oral health and is recommended '
          'at least twice a year for most patients.',
      category: TreatmentCategory.general,
      icon: Icons.cleaning_services_rounded,
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
      shortDescription: 'Restore cavities with tooth-colored composite resin.',
      longDescription:
          'A dental filling repairs a tooth damaged by decay, restoring its normal shape '
          'and function while preventing further decay. Modern composite (tooth-colored) '
          'fillings bond directly to the tooth structure and are virtually invisible.',
      category: TreatmentCategory.general,
      icon: Icons.healing_rounded,
      iconColor: Color(0xFF4CAF93),
      iconBackground: Color(0xFFE8F5F1),
      duration: '30 – 60 minutes',
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
      shortDescription: 'Treat infected tooth pulp and save the natural tooth.',
      longDescription:
          'Root canal therapy removes infected or inflamed pulp tissue from inside the '
          'tooth, cleans and shapes the root canals, then seals the space to prevent '
          'reinfection. Despite its reputation, modern root canals are no more '
          'uncomfortable than having a filling placed.',
      category: TreatmentCategory.general,
      icon: Icons.medical_services_rounded,
      iconColor: Color(0xFFE8896A),
      iconBackground: Color(0xFFFDF0EB),
      duration: '60 – 90 minutes',
      requiresFollowUp: true,
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
      shortDescription: 'Safe removal of a severely damaged or impacted tooth.',
      longDescription:
          'Tooth extraction removes a tooth that cannot be saved by other treatments. '
          'Simple extractions are performed on visible teeth while surgical extractions '
          'handle teeth broken at the gumline or impacted wisdom teeth.',
      category: TreatmentCategory.general,
      icon: Icons.remove_circle_outline_rounded,
      iconColor: Color(0xFFF4A261),
      iconBackground: Color(0xFFFEF4EC),
      duration: '20 – 45 minutes',
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
      shortDescription: 'Brighten your smile with safe professional whitening.',
      longDescription:
          'Professional teeth whitening uses a higher concentration of bleaching agents '
          'than over-the-counter products, achieving noticeably brighter results in a '
          'single visit. The procedure is safe, fast, and overseen by a dental professional.',
      category: TreatmentCategory.cosmetic,
      icon: Icons.auto_awesome_rounded,
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
      shortDescription: 'Ultra-thin shells that transform the look of your smile.',
      longDescription:
          'Porcelain or composite veneers are wafer-thin shells custom-made to cover '
          'the front surface of teeth, correcting discolouration, chips, gaps, and '
          'minor misalignment in a minimally invasive way.',
      category: TreatmentCategory.cosmetic,
      icon: Icons.star_outline_rounded,
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
      shortDescription: 'Braces and aligners for a straighter, perfect smile.',
      longDescription:
          'Orthodontic treatment straightens teeth and corrects bite issues using '
          'fixed braces or removable clear aligners. Treatment not only improves '
          'aesthetics but also makes teeth easier to clean and reduces jaw strain.',
      category: TreatmentCategory.orthodontics,
      icon: Icons.grid_3x3_rounded,
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
      shortDescription: 'Nearly invisible trays that gradually straighten teeth.',
      longDescription:
          'Clear aligner therapy uses a series of custom, removable plastic trays to '
          'move teeth incrementally. Each tray is slightly different, gently guiding '
          'teeth toward the target position over several months.',
      category: TreatmentCategory.orthodontics,
      icon: Icons.visibility_off_rounded,
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
      shortDescription: 'Permanent titanium roots for replacing missing teeth.',
      longDescription:
          'Dental implants are titanium posts surgically placed into the jawbone to '
          'act as artificial tooth roots. They provide a stable, long-lasting foundation '
          'for replacement teeth that look, feel, and function exactly like natural ones.',
      category: TreatmentCategory.surgical,
      icon: Icons.hardware_rounded,
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
      shortDescription: 'Surgical extraction of impacted or problematic wisdom teeth.',
      longDescription:
          'Wisdom teeth (third molars) often emerge at an angle or become trapped '
          '(impacted) in the jawbone, causing pain, crowding, and infection risk. '
          'Surgical removal prevents these complications and relieves discomfort.',
      category: TreatmentCategory.surgical,
      icon: Icons.cut_rounded,
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
  ];

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
