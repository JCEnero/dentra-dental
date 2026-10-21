import 'tooth_catalog.dart';

/// What every tooth of a type shares: its job, common problems and care.
class ToothTypeContent {
  const ToothTypeContent({
    required this.summary,
    required this.function,
    required this.concerns,
    required this.hygiene,
  });

  /// One line for the legend.
  final String summary;
  final String function;
  final List<String> concerns;
  final List<String> hygiene;
}

/// What is specific to one position in one arch.
class ToothPositionContent {
  const ToothPositionContent({
    required this.eruption,
    required this.roots,
    required this.anatomy,
    required this.fact,
  });

  /// Typical eruption age of the permanent tooth.
  final String eruption;
  final String roots;
  final List<String> anatomy;
  final String fact;
}

abstract class ToothContent {
  static ToothTypeContent forType(ToothType type) => _types[type]!;

  static ToothPositionContent forTooth(ToothInfo tooth) =>
      (tooth.arch == ToothArch.upper ? _upper : _lower)[tooth.position - 1];

  /// Explains the tooth's number, e.g. "Quadrant 3 (lower left) ·
  /// position 6 from the midline".
  static String numberBreakdown(ToothInfo tooth) =>
      'Quadrant ${tooth.quadrant} (${tooth.quadrantName.toLowerCase()}) · '
      'position ${tooth.position} from the midline';

  static const List<String> facts = [
    'Adults usually have 32 permanent teeth, including four wisdom teeth.',
    'Enamel is the hardest substance in the human body.',
    'More than half of each tooth\'s length is root, hidden under the gums.',
    'Flossing cleans the tooth surfaces between teeth that a brush cannot reach.',
    'Children have 20 baby teeth, which are replaced from about age six.',
  ];
}

const Map<ToothType, ToothTypeContent> _types = {
  ToothType.incisor: ToothTypeContent(
    summary: 'Thin, chisel-shaped front teeth for biting',
    function: 'Biting and cutting food into smaller pieces. Incisors also help '
        'shape sounds like "f", "v" and "th", and support the lips.',
    concerns: [
      'Chips and fractures from falls, sports or biting hard objects',
      'Wear along the biting edge from grinding',
      'Surface stains from coffee, tea or smoking',
      'Crowding or gaps that affect alignment',
      'Tartar build-up behind the lower incisors',
    ],
    hygiene: [
      'Tilt the brush upright to clean the inner surfaces',
      'Floss daily between these tight contacts',
      'Wear a mouthguard for contact sports',
      'Avoid using front teeth to open packaging',
    ],
  ),
  ToothType.canine: ToothTypeContent(
    summary: 'Pointed corner teeth for gripping and tearing',
    function: 'Gripping and tearing food. Canines also guide the jaw in '
        'side-to-side movements, which protects the back teeth.',
    concerns: [
      'Gum recession over the prominent root',
      'Notches at the gumline from brushing too hard',
      'Impaction, mostly upper canines that fail to come through',
      'Wear of the pointed tip from grinding',
    ],
    hygiene: [
      'Use a soft brush and gentle pressure at the gumline',
      'Follow the curve of the tooth with small circles',
      'Avoid scrubbing sideways, which wears the root surface',
    ],
  ),
  ToothType.premolar: ToothTypeContent(
    summary: 'Two-cusped teeth that crush and tear',
    function: 'Crushing and tearing food. Premolars hand chewing over from the '
        'canines to the molars and help support the cheeks.',
    concerns: [
      'Decay in the pits and grooves of the chewing surface',
      'Cracks, especially in upper first premolars',
      'Wear and gum recession at the gumline',
      'Sometimes removed to make space during orthodontic treatment',
    ],
    hygiene: [
      'Brush the chewing surface with short back-and-forth strokes',
      'Floss the contacts next to the canine and first molar',
      'Ask your dentist whether sealants suit deep grooves',
    ],
  ),
  ToothType.molar: ToothTypeContent(
    summary: 'Broad back teeth for grinding',
    function:
        'Grinding and chewing food. Molars take most of the chewing force '
        'and hold up the height of the bite.',
    concerns: [
      'Cavities in deep grooves and between teeth',
      'Cracked cusps, especially around large fillings',
      'Gum disease where the roots split (the furcation)',
      'Wisdom teeth that are impacted or only partly through',
    ],
    hygiene: [
      'Open wide and angle the brush to reach the very back',
      'Clean the back side of the last tooth in each row',
      'Use floss or interdental brushes between molars',
      'Sealants can protect the grooves of children\'s molars',
    ],
  ),
};

const List<ToothPositionContent> _upper = [
  ToothPositionContent(
    eruption: '7–8 years',
    roots: '1 conical root',
    anatomy: [
      'Widest front tooth, with a broad, flat front surface',
      'Straight biting edge; young teeth show small bumps called mamelons',
      'Shovel-shaped back surface framed by marginal ridges',
    ],
    fact: 'Upper central incisors are the most visible teeth in a smile '
        'and set its overall proportions.',
  ),
  ToothPositionContent(
    eruption: '8–9 years',
    roots: '1 slender root',
    anatomy: [
      'A smaller, rounder version of the central incisor',
      'More rounded biting corners, especially the outer one',
      'May have a deep pit on the back surface, a common spot for decay',
    ],
    fact: 'Upper lateral incisors are among the teeth most often missing '
        'from birth or small and peg-shaped.',
  ),
  ToothPositionContent(
    eruption: '11–12 years',
    roots: '1 root, the longest in the mouth',
    anatomy: [
      'One pointed cusp with a front and back slope',
      'Raised ridge running down the middle of the front surface',
      'Strong bulge (cingulum) near the gum on the palate side',
    ],
    fact: 'At about 27 mm from tip to root end, the upper canine is usually '
        'the longest tooth in the mouth.',
  ),
  ToothPositionContent(
    eruption: '10–11 years',
    roots: 'Usually 2 roots (cheek and palate side)',
    anatomy: [
      'Two cusps; the cheek-side cusp is slightly taller',
      'A small hollow on the front-facing side of the crown',
      'A central groove crossing the chewing surface',
    ],
    fact: 'It is the only premolar that usually has two roots.',
  ),
  ToothPositionContent(
    eruption: '10–12 years',
    roots: '1 root',
    anatomy: [
      'Two cusps of nearly equal height',
      'Short central groove with extra small grooves around it',
      'Rounder and more symmetrical than the first premolar',
    ],
    fact: 'Upper first and second premolars look so alike that they are '
        'often mixed up, even by dental students.',
  ),
  ToothPositionContent(
    eruption: '6–7 years',
    roots: '3 roots (2 cheek side, 1 palate side)',
    anatomy: [
      'Four main cusps; the front palate-side cusp is the largest',
      'An oblique ridge runs diagonally across the chewing surface',
      'Often a small extra cusp (cusp of Carabelli) on the palate side',
    ],
    fact: 'It comes through behind the baby teeth at about age six, so it is '
        'often mistaken for a baby tooth.',
  ),
  ToothPositionContent(
    eruption: '12–13 years',
    roots: '3 roots, closer together',
    anatomy: [
      'Smaller and more heart-shaped than the first molar',
      'The back palate-side cusp is small or missing',
      'Usually no Carabelli cusp',
    ],
    fact: 'It is often called the "12-year molar" because of when it '
        'appears.',
  ),
  ToothPositionContent(
    eruption: '17–21 years',
    roots: 'Variable, often fused together',
    anatomy: [
      'The most variable tooth in the upper arch',
      'Usually three cusps in a heart-shaped outline',
      'Often only partly erupted, or stuck (impacted)',
    ],
    fact: 'Many people never develop some or all of their wisdom teeth.',
  ),
];

const List<ToothPositionContent> _lower = [
  ToothPositionContent(
    eruption: '6–7 years',
    roots: '1 narrow, flattened root',
    anatomy: [
      'The smallest tooth in the permanent set',
      'Symmetrical crown with a straight biting edge',
      'Root is thin side to side but wide front to back',
    ],
    fact: 'Lower central incisors are among the first permanent teeth to '
        'come through, along with the first molars.',
  ),
  ToothPositionContent(
    eruption: '7–8 years',
    roots: '1 root',
    anatomy: [
      'Slightly wider than the lower central incisor',
      'Biting edge twists slightly toward the tongue',
      'Outer corner a little more rounded than the inner one',
    ],
    fact: 'Tartar often collects behind the lower front teeth because '
        'salivary glands open just below them.',
  ),
  ToothPositionContent(
    eruption: '9–10 years',
    roots: '1 root, occasionally split in two',
    anatomy: [
      'Narrower and more slender than the upper canine',
      'Smaller bulge and ridges on the tongue side',
      'Long crown with a pointed cusp',
    ],
    fact: 'The lower canine is the only lower front tooth that sometimes '
        'has two roots.',
  ),
  ToothPositionContent(
    eruption: '10–12 years',
    roots: '1 root',
    anatomy: [
      'Large cheek-side cusp and a tiny tongue-side cusp',
      'Crown leans toward the tongue',
      'From the side it looks like a small canine',
    ],
    fact: 'Its tiny tongue-side cusp makes it a transition between a canine '
        'and a premolar.',
  ),
  ToothPositionContent(
    eruption: '11–12 years',
    roots: '1 root',
    anatomy: [
      'Often three cusps (one cheek side, two tongue side) in a Y pattern',
      'Larger and squarer than the first premolar',
      'Well-developed tongue-side cusps',
    ],
    fact: 'After wisdom teeth, it is one of the teeth most often missing '
        'from birth.',
  ),
  ToothPositionContent(
    eruption: '6–7 years',
    roots: '2 roots (front and back)',
    anatomy: [
      'The largest lower tooth, with five cusps: three cheek side, two tongue side',
      'Tongue-side cusps stand taller than cheek-side cusps',
      'Two widely spread roots',
    ],
    fact: 'Because it comes through so early, it is often the first '
        'permanent tooth to need a filling.',
  ),
  ToothPositionContent(
    eruption: '11–13 years',
    roots: '2 roots, closer together',
    anatomy: [
      'Four cusps of similar size',
      'Grooves on the chewing surface form a plus sign',
      'Shorter, less spread roots than the first molar',
    ],
    fact: 'Its plus-shaped groove pattern is a classic way to tell it apart '
        'from the first molar.',
  ),
  ToothPositionContent(
    eruption: '17–21 years',
    roots: '2 roots, often fused or curved',
    anatomy: [
      'Variable crown, usually with four or five cusps',
      'Wrinkled chewing surface with many small grooves',
      'Frequently stuck (impacted) in the jawbone',
    ],
    fact: 'Lower wisdom teeth become impacted more often than upper ones.',
  ),
];
