import 'dart:async';

import 'package:dentra_mobile/app/app.dart';
import 'package:dentra_mobile/features/auth/providers/auth_provider.dart';
import 'package:dentra_mobile/features/auth/screens/login_screen.dart';
import 'package:dentra_mobile/features/auth/services/auth_service.dart';
import 'package:dentra_mobile/features/dental_profile/data/dental_questions.dart';
import 'package:dentra_mobile/features/dental_profile/data/models/dental_answers.dart';
import 'package:dentra_mobile/features/dental_profile/data/questionnaire_draft_store.dart';
import 'package:dentra_mobile/features/dental_profile/providers/dental_profile_providers.dart';
import 'package:dentra_mobile/features/dental_profile/screens/dental_questionnaire_screen.dart';
import 'package:dentra_mobile/features/dental_profile/state/dental_questionnaire_controller.dart';
import 'package:dentra_mobile/features/dental_profile/widgets/answer_option_tile.dart';
import 'package:dentra_mobile/features/dental_profile/widgets/prompt_care_note.dart';
import 'package:dentra_mobile/features/dental_profile/widgets/question_block.dart';
import 'package:dentra_mobile/features/screening/data/models/screening_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_dental_profile_repository.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('answers', () {
    test('"none" answers are exclusive in both directions', () {
      var a = const DentalAnswers()
          .toggle(DentalQuestionId.currentConcerns, CurrentConcern.toothPain)
          .toggle(
              DentalQuestionId.currentConcerns, CurrentConcern.bleedingGums);
      expect(a.currentConcerns,
          {CurrentConcern.toothPain, CurrentConcern.bleedingGums});

      a = a.toggle(DentalQuestionId.currentConcerns, CurrentConcern.none);
      expect(a.currentConcerns, {CurrentConcern.none});

      a = a.toggle(
          DentalQuestionId.currentConcerns, CurrentConcern.sensitivity);
      expect(a.currentConcerns, {CurrentConcern.sensitivity});
    });

    test('follow-up questions depend on the reported concern', () {
      const none = DentalAnswers(currentConcerns: {CurrentConcern.none});
      expect(none.asksConcernDuration, isFalse);
      expect(none.asksDiscomfort, isFalse);

      const notSure = DentalAnswers(currentConcerns: {CurrentConcern.notSure});
      expect(notSure.asksConcernDuration, isFalse);

      // A spot doesn't hurt: how long, but not how it feels.
      const spot =
          DentalAnswers(currentConcerns: {CurrentConcern.discoloration});
      expect(spot.asksConcernDuration, isTrue);
      expect(spot.asksDiscomfort, isFalse);

      const pain = DentalAnswers(currentConcerns: {CurrentConcern.toothPain});
      expect(pain.asksConcernDuration, isTrue);
      expect(pain.asksDiscomfort, isTrue);
    });

    test('saving drops hidden follow-ups and details without their option', () {
      final a = sampleAnswers
          .toggle(DentalQuestionId.currentConcerns, CurrentConcern.none)
          .copyWith(
              previousProblemsOther: 'left over', additionalInformation: '  ');
      final json = a.toJson();
      expect(json['current_concerns'], ['none']);
      expect(json['concern_duration'], isNull);
      expect(json['discomfort_level'], isNull);
      expect(json['previous_problems_other'], isNull);
      expect(json['additional_information'], isNull);
      // ...but they are kept while editing, so toggling back restores them.
      expect(a.concernDuration, ConcernDuration.fewWeeks);
    });

    test('ids sent to the API match the backend', () {
      expect(sampleAnswers.toJson(), {
        'last_checkup': 'over_1_year',
        'previous_problems': ['tooth_decay'],
        'previous_problems_other': null,
        'current_concerns': ['tooth_pain'],
        'current_concerns_other': null,
        'concern_duration': 'few_weeks',
        'discomfort_level': 'moderate',
        'screening_goals': ['decay'],
        'screening_goals_detail': null,
        'difficult_areas': ['back_teeth'],
        'dental_appliances': <String>[],
        'dental_appliances_other': null,
        'past_treatments': <String>[],
        'last_cleaning': null,
        'brushing': null,
        'between_teeth': null,
        'health_factors': <String>[],
        'additional_information': null,
      });
    });

    test('unknown ids in stored data are ignored, not fatal', () {
      final a = DentalAnswers.fromJson({
        'last_checkup': 'someday',
        'current_concerns': ['tooth_pain', 'from_a_newer_app'],
      });
      expect(a.lastCheckup, isNull);
      expect(a.currentConcerns, {CurrentConcern.toothPain});
    });

    test('severe discomfort calls for prompt care', () {
      expect(sampleAnswers.needsPromptCare, isFalse);
      expect(
        sampleAnswers
            .copyWith(discomfortLevel: DiscomfortLevel.severe)
            .needsPromptCare,
        isTrue,
      );
    });
  });

  group('controller', () {
    test('Continue is blocked until required questions are answered', () {
      final c = DentalQuestionnaireController(initial: const DentalAnswers());
      expect(c.next(), isFalse);
      expect(c.errors.keys, {DentalQuestionId.lastCheckup});

      c.toggle(DentalQuestionId.lastCheckup, LastCheckup.never);
      expect(c.errors, isEmpty);
      expect(c.next(), isTrue);
      expect(c.step, 1);

      // Past problems has its own slide.
      expect(c.next(), isFalse);
      expect(c.errors.keys, {DentalQuestionId.previousProblems});
      c.toggle(DentalQuestionId.previousProblems, PreviousProblem.none);
      expect(c.next(), isTrue);
      expect(c.step, 2);
    });

    test('going back keeps every answer', () {
      final c = DentalQuestionnaireController(initial: sampleAnswers);
      c.next();
      c.next();
      c.back();
      c.back();
      expect(c.step, 0);
      expect(c.answers, sampleAnswers);
    });

    test('only the optional step can be skipped, and only when empty', () {
      final c = DentalQuestionnaireController(initial: sampleAnswers);
      expect(c.canSkip, isFalse);
      c
        ..next()
        ..next()
        ..next()
        ..next();
      expect(c.currentStep!.optional, isTrue);
      expect(c.canSkip, isTrue);
      c.toggle(DentalQuestionId.pastTreatments, PastTreatment.filling);
      expect(c.canSkip, isFalse);
    });

    test('a double submit sends once', () async {
      final c = DentalQuestionnaireController(
        initial: sampleAnswers,
        initialStep: DentalQuestionnaireController.reviewStep,
      );
      final release = Completer<void>();
      var calls = 0;
      Future<void> save(DentalAnswers _) {
        calls++;
        return release.future;
      }

      final first = c.submit(save);
      final second = c.submit(save);
      expect(await second, isFalse);
      release.complete();
      expect(await first, isTrue);
      expect(calls, 1);
    });

    test('a failed save keeps the answers and explains', () async {
      final c = DentalQuestionnaireController(
        initial: sampleAnswers,
        initialStep: DentalQuestionnaireController.reviewStep,
      );
      final ok = await c.submit((_) async => throw offline);
      expect(ok, isFalse);
      expect(c.submitError, offline.message);
      expect(c.submitting, isFalse);
      expect(c.answers, sampleAnswers);
    });

    test('every change is saved as a draft', () async {
      final store = MemoryQuestionnaireDraftStore();
      final c = DentalQuestionnaireController(
        initial: const DentalAnswers(),
        draftStore: store,
        draftOwner: 'u1',
      );
      c.toggle(DentalQuestionId.lastCheckup, LastCheckup.never);
      c.next();
      await pumpEventQueue();
      final draft = store.drafts['u1']!;
      expect(draft.step, 1);
      expect(draft.answers.lastCheckup, LastCheckup.never);
    });
  });

  test('screening sessions keep reported context apart from findings', () {
    final session = ScreeningSession.fromJson({
      'id': 's1',
      'completed_at': '2026-10-21T08:00:00Z',
      'captured_regions': ['ul'],
      'total_regions': 5,
      'analysis': null,
      'reported_context': {
        'source': 'user_reported',
        'profile_version': 3,
        'current_concerns': ['tooth_pain'],
        'concern_duration': 'few_days',
        'discomfort_level': 'severe',
        'screening_goals': ['decay'],
        'difficult_areas': ['back_teeth'],
        'dental_appliances': [],
        'recorded_at': '2026-10-21T08:00:00Z',
      },
    });
    // Reported pain is context, not a detection.
    expect(session.analysis, isNull);
    final ctx = session.reportedContext!;
    expect(ctx.profileVersion, 3);
    expect(ctx.currentConcerns, {CurrentConcern.toothPain});
    expect(ctx.discomfortLevel, DiscomfortLevel.severe);

    // Survives updates such as saving an analysis later.
    final withAnalysis = session.copyWith(
      analysis: ScreeningAnalysis(summary: 'x', analyzedAt: DateTime(2026)),
    );
    expect(withAnalysis.reportedContext, same(ctx));
    expect(withAnalysis.analysis!.findings, isEmpty);
  });

  group('sign-in to dashboard', () {
    late AuthService auth;
    late FakeDentalProfileRepository repo;
    late MemoryQuestionnaireDraftStore drafts;

    setUp(() {
      auth = AuthService(); // demo mode
      repo = FakeDentalProfileRepository();
      drafts = MemoryQuestionnaireDraftStore();
    });

    Future<void> signIn(WidgetTester tester) => tester.runAsync(() =>
        auth.signInWithEmail(email: 'ana@dentra.com', password: 'secret123'));

    /// The real gate, with a stand-in for the app shell.
    Future<void> pumpGate(WidgetTester tester, {Widget? home}) async {
      tester.view.physicalSize = const Size(390, 844) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          authServiceProvider.overrideWith((ref) => auth),
          dentalProfileRepositoryProvider.overrideWithValue(repo),
          questionnaireDraftStoreProvider.overrideWithValue(drafts),
        ],
        child: MaterialApp(
          home: home ?? const SignedInGate(app: Text('DASHBOARD')),
          routes: {
            '/home': (_) => const SignedInGate(app: Text('DASHBOARD')),
          },
        ),
      ));
      await settle(tester);
    }

    testWidgets('a new account goes to the questionnaire, not the dashboard',
        (tester) async {
      // Registration hands over to '/home' once the account exists.
      await pumpGate(
        tester,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              await auth.registerWithEmail(
                fullName: 'Ana Cruz',
                email: 'ana@dentra.com',
                password: 'secret123',
              );
              if (context.mounted) {
                Navigator.of(context)
                    .pushNamedAndRemoveUntil('/home', (_) => false);
              }
            },
            child: const Text('Create account'),
          ),
        ),
      );
      await tester.tap(find.text('Create account'));
      // Demo sign-up takes 1.6 s.
      await tester.pump(const Duration(milliseconds: 1700));
      await settle(tester);

      expect(find.byType(DentalQuestionnaireScreen), findsOneWidget);
      expect(find.text('Let’s set up your dental profile'), findsOneWidget);
      expect(find.text('DASHBOARD'), findsNothing);
    });

    testWidgets('a returning user goes straight to the dashboard',
        (tester) async {
      repo.profile = savedProfile(sampleAnswers);
      await signIn(tester);
      await pumpGate(tester);
      expect(find.text('DASHBOARD'), findsOneWidget);
      expect(find.byType(DentalQuestionnaireScreen), findsNothing);
    });

    testWidgets(
        'completing the questionnaire saves it, then opens the dashboard '
        'only once the save is confirmed', (tester) async {
      await signIn(tester);
      await pumpGate(tester);

      // A fresh start opens on the welcome slide.
      expect(find.text('Let’s set up your dental profile'), findsOneWidget);
      await tapButton(tester, 'Get started');

      // Step 1 is split: one question per slide.
      await choose(
          tester, 'When was your last dental checkup?', 'More than a year ago');
      expect(
          find.text('Have you had any dental problems before?'), findsNothing);
      await tapButton(tester, 'Continue');
      await choose(tester, 'Have you had any dental problems before?',
          'Tooth decay or cavities');
      await tapButton(tester, 'Continue');

      await choose(tester, 'right now?', 'Tooth pain');
      await choose(tester, 'How long', 'A few weeks');
      await choose(tester, 'discomfort', 'Moderate');
      await tapButton(tester, 'Continue');

      await choose(tester, 'What would you most like to check',
          'Possible tooth decay or cavities');
      await choose(tester, 'hard for you to see', 'Back teeth or molars');
      await tapButton(tester, 'Continue');

      await tapButton(tester, 'Skip this step');
      await tapButton(tester, 'Skip this step');
      expect(find.text('Review your answers'), findsOneWidget);
      expect(find.text('Tooth pain'), findsOneWidget);

      repo.holdSave = Completer<void>();
      await tapButton(tester, 'Save and continue');
      // Pending: still here, and a second tap sends nothing more.
      expect(find.text('DASHBOARD'), findsNothing);
      expect(find.bySemanticsLabel('Saving…'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Saving…'));
      await tester.pump();

      repo.holdSave!.complete();
      await settle(tester);
      expect(find.text('DASHBOARD'), findsOneWidget);
      expect(repo.submitted, hasLength(1));
      expect(repo.submitted.single, sampleAnswers);
      // The finished draft is gone.
      expect(drafts.drafts, isEmpty);
    });

    testWidgets('a failed save keeps the user and their answers',
        (tester) async {
      drafts.drafts['stub-uid-001'] = const QuestionnaireDraft(
        answers: sampleAnswers,
        step: 6, // review
      );
      repo.saveError = offline;
      await signIn(tester);
      await pumpGate(tester);

      await tapButton(tester, 'Save and continue');
      expect(find.text(offline.message), findsOneWidget);
      expect(find.text('DASHBOARD'), findsNothing);
      expect(find.text('Review your answers'), findsOneWidget);
      expect(find.text('More than a year ago'), findsOneWidget);
      expect(drafts.drafts, isNotEmpty);

      // Back online: retrying works.
      repo.saveError = null;
      await tapButton(tester, 'Save and continue');
      expect(find.text('DASHBOARD'), findsOneWidget);
    });

    testWidgets('an unfinished questionnaire resumes after signing back in',
        (tester) async {
      await signIn(tester);
      await pumpGate(tester);
      await tapButton(tester, 'Get started');
      await choose(tester, 'When was your last dental checkup?',
          'I have never had a dental checkup');
      await tapButton(tester, 'Continue');
      await choose(
          tester, 'Have you had any dental problems before?', 'Gum problems');
      await tapButton(tester, 'Continue');
      expect(find.text(dentalSteps[2].summary!), findsOneWidget);

      await auth.signOut();
      await settle(tester);
      expect(find.byType(LoginScreen), findsOneWidget);

      // Signed in on fake time: real async here would let font loading
      // run in the test host.
      final signedIn =
          auth.signInWithEmail(email: 'ana@dentra.com', password: 'secret123');
      await tester.pump(const Duration(milliseconds: 1500));
      await signedIn;
      await settle(tester);
      // Straight back to the slide, no welcome.
      expect(find.text(dentalSteps[2].summary!), findsOneWidget);
      await tapButton(tester, 'Back');
      expect(selected(tester, 'Gum problems'), isTrue);
      await tapButton(tester, 'Back');
      expect(selected(tester, 'I have never had a dental checkup'), isTrue);
    });

    testWidgets('follow-up questions appear only when they apply',
        (tester) async {
      drafts.drafts['stub-uid-001'] = const QuestionnaireDraft(
        answers: DentalAnswers(),
        step: 2,
      );
      await signIn(tester);
      await pumpGate(tester);

      expect(find.textContaining('How long'), findsNothing);
      expect(find.textContaining('discomfort right now'), findsNothing);

      await choose(
          tester, 'right now?', 'Visible spots or discoloration on teeth');
      expect(find.textContaining('How long'), findsOneWidget);
      expect(find.textContaining('discomfort right now'), findsNothing);

      await choose(tester, 'right now?', 'Tooth pain');
      expect(find.textContaining('discomfort right now'), findsOneWidget);
      expect(find.text('Your own description, not a clinical pain assessment.'),
          findsOneWidget);

      await choose(tester, 'discomfort', 'Severe');
      expect(find.text(PromptCareNote.title), findsOneWidget);

      await choose(tester, 'right now?', 'No current concerns');
      expect(find.textContaining('How long'), findsNothing);
      expect(find.textContaining('discomfort right now'), findsNothing);
      expect(find.text(PromptCareNote.title), findsNothing);
      expect(selected(tester, 'Tooth pain'), isFalse);

      // "Another concern" opens its description box.
      await choose(tester, 'right now?', 'Another concern');
      expect(find.text('Your concern (optional)'), findsOneWidget);
    });

    testWidgets('offline at launch: retry, never assume onboarding is done',
        (tester) async {
      repo.statusError = offline;
      await signIn(tester);
      await pumpGate(tester);
      expect(find.text("We couldn't load your profile"), findsOneWidget);
      expect(find.text('DASHBOARD'), findsNothing);
      expect(find.byType(DentalQuestionnaireScreen), findsNothing);

      await tapButton(tester, 'Try again');
      expect(find.byType(DentalQuestionnaireScreen), findsOneWidget);
    });

    testWidgets('offline at launch, after the server confirmed completion',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'dental_profile.onboarding_completed.v1.stub-uid-001': true,
      });
      repo.statusError = offline;
      await signIn(tester);
      await pumpGate(tester);
      expect(find.text('DASHBOARD'), findsOneWidget);
    });
  });

  for (final (name, size, scale) in [
    ('small phone, large text', const Size(320, 568), 2.0),
    ('standard phone', const Size(390, 844), 1.0),
  ]) {
    testWidgets('lays out without overflow: $name', (tester) async {
      tester.view.physicalSize = size * 3;
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final auth = AuthService();
      await tester.runAsync(() =>
          auth.signInWithEmail(email: 'ana@dentra.com', password: 'secret123'));
      final drafts = MemoryQuestionnaireDraftStore()
        ..drafts['stub-uid-001'] = QuestionnaireDraft(
          // Every follow-up and the care note showing.
          answers: sampleAnswers.copyWith(
            discomfortLevel: DiscomfortLevel.severe,
            currentConcerns: {CurrentConcern.toothPain, CurrentConcern.other},
            currentConcernsOther: 'Clicking jaw',
          ),
          step: 2,
        );
      await tester.pumpWidget(ProviderScope(
        overrides: [
          authServiceProvider.overrideWith((ref) => auth),
          dentalProfileRepositoryProvider
              .overrideWithValue(FakeDentalProfileRepository()),
          questionnaireDraftStoreProvider.overrideWithValue(drafts),
        ],
        child: const MaterialApp(home: SignedInGate(app: Text('DASHBOARD'))),
      ));
      await settle(tester);
      expect(find.text(PromptCareNote.title), findsOneWidget);
      expect(tester.takeException(), isNull);

      // The action bar stays on screen.
      final action = tester.getRect(find.bySemanticsLabel('Continue'));
      expect(action.bottom, lessThanOrEqualTo(size.height));

      await tapButton(tester, 'Continue');
      await tapButton(tester, 'Continue');
      await tapButton(tester, 'Skip this step');
      await tapButton(tester, 'Skip this step');
      expect(find.text('Review your answers'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  group('editing from Profile', () {
    testWidgets('opens on review and saves only real changes', (tester) async {
      tester.view.physicalSize = const Size(390, 844) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final auth = AuthService();
      await tester.runAsync(() =>
          auth.signInWithEmail(email: 'ana@dentra.com', password: 'secret123'));
      final repo = FakeDentalProfileRepository.completed();
      bool? result;

      await tester.pumpWidget(ProviderScope(
        overrides: [
          authServiceProvider.overrideWith((ref) => auth),
          dentalProfileRepositoryProvider.overrideWithValue(repo),
          // Tests never reach the platform keychain.
          questionnaireDraftStoreProvider
              .overrideWithValue(MemoryQuestionnaireDraftStore()),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await Navigator.of(context)
                  .push(DentalQuestionnaireScreen.editRoute(repo.profile!)),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await settle(tester);

      expect(find.text('Your dental profile'), findsOneWidget);
      // Nothing changed yet: nothing to save.
      await tapButton(tester, 'Save changes');
      expect(repo.updated, isEmpty);

      await tester.tap(find.bySemanticsLabel('Edit last dental checkup'));
      await settle(tester);
      await choose(tester, 'When was your last dental checkup?',
          'Within the last 6 months');
      await tapButton(tester, 'Back to review');
      await tapButton(tester, 'Save changes');

      expect(repo.updated, hasLength(1));
      expect(repo.updated.single.lastCheckup, LastCheckup.within6Months);
      expect(repo.submitted, isEmpty);
      expect(result, isTrue);
    });
  });
}

// ── Helpers ──────────────────────────────────────────────────────────────────

/// Pumps through transitions without waiting on endless spinners.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Taps [answer] under the question whose title contains [question].
Future<void> choose(WidgetTester tester, String question, String answer) async {
  final option = find.descendant(
    of: find.ancestor(
      of: find.textContaining(question),
      matching: find.byType(QuestionBlock),
    ),
    matching: find.text(answer),
  );
  await tester.ensureVisible(option);
  await tester.pump();
  await tester.tap(option);
  await settle(tester);
}

/// Taps a button by its label, or an icon button by its tooltip.
Future<void> tapButton(WidgetTester tester, String label) async {
  final labelled = find.bySemanticsLabel(label);
  final button = labelled.evaluate().isEmpty ? find.byTooltip(label) : labelled;
  await tester.ensureVisible(button.first);
  await tester.tap(button.first);
  await settle(tester);
}

/// Whether the answer row labelled [label] is checked.
bool selected(WidgetTester tester, String label) => tester
    .widget<AnswerOptionTile>(find.ancestor(
      of: find.text(label),
      matching: find.byType(AnswerOptionTile),
    ))
    .selected;
