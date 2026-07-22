import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pet_passport/l10n/generated/app_l10n.dart';

import '../../insurances/domain/insurance.dart';
import '../../pets/domain/pet.dart';
import '../../pets/domain/pet_enums.dart';
import '../../vaccinations/domain/vaccination.dart';
import '../../vets/domain/vet.dart';

/// Shared inputs for every PDF document. The service assembles this bundle
/// once and hands it to whichever builder the user picked.
class PdfBundle {
  const PdfBundle({
    required this.pet,
    required this.vaccinations,
    required this.vets,
    required this.insurances,
    required this.latestWeight,
    required this.profilePhotoAbsPath,
    required this.locale,
    required this.l,
  });

  final Pet pet;
  final List<Vaccination> vaccinations;
  final List<Vet> vets;
  final List<Insurance> insurances;
  final PetWeight? latestWeight;
  final String? profilePhotoAbsPath;
  final String locale;
  final AppL10n l;
}

/// Loads a Unicode-safe TTF for rendering (default Helvetica in `pdf`
/// package chokes on ä/ö/ü/ß). Falls back to Helvetica if the asset
/// isn't shipped — better to render than to crash.
Future<pw.ThemeData> _loadTheme() async {
  try {
    final data =
        await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    return pw.ThemeData.withFont(base: pw.Font.ttf(data));
  } catch (_) {
    return pw.ThemeData();
  }
}

Future<pw.MemoryImage?> _loadProfileImage(String? absPath) async {
  if (absPath == null) return null;
  try {
    final bytes = await File(absPath).readAsBytes();
    return pw.MemoryImage(bytes);
  } catch (_) {
    return null;
  }
}

/// ── Vaccination passport ────────────────────────────────────────────────
Future<pw.Document> buildVaccinationPassport(PdfBundle b) async {
  final doc = pw.Document();
  final theme = await _loadTheme();
  final photo = await _loadProfileImage(b.profilePhotoAbsPath);
  final dateFmt = DateFormat.yMd(b.locale);

  doc.addPage(
    pw.MultiPage(
      theme: theme,
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (ctx) => [
        _header(b, photo, b.l.pdfPassportTitle),
        if (b.pet.vaccinationPassportNumber != null &&
            b.pet.vaccinationPassportNumber!.isNotEmpty) ...[
          pw.SizedBox(height: 6),
          pw.Text(
            '${b.l.passportNumberLabel}: ${b.pet.vaccinationPassportNumber}',
            style: pw.TextStyle(
                fontSize: 11, color: PdfColors.grey700),
          ),
        ],
        pw.SizedBox(height: 16),
        pw.Text(b.l.pdfVaccinationsSection,
            style: pw.TextStyle(
                fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        if (b.vaccinations.isEmpty)
          pw.Text(b.l.pdfNoVaccinations)
        else
          pw.TableHelper.fromTextArray(
            headers: [
              b.l.pdfColDate,
              b.l.pdfColVaccine,
              b.l.pdfColBatch,
              b.l.pdfColNextDue,
              b.l.pdfColVet,
            ],
            data: [
              for (final v in b.vaccinations)
                [
                  dateFmt.format(v.administeredAt),
                  v.vaccineName,
                  v.batchNumber ?? '—',
                  v.nextDueAt == null ? '—' : dateFmt.format(v.nextDueAt!),
                  _vetName(b.vets, v.vetUuid),
                ],
            ],
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellStyle: const pw.TextStyle(fontSize: 10),
          ),
        _footer(b),
      ],
    ),
  );
  return doc;
}

/// ── Pet overview ────────────────────────────────────────────────────────
Future<pw.Document> buildPetOverview(PdfBundle b) async {
  final doc = pw.Document();
  final theme = await _loadTheme();
  final photo = await _loadProfileImage(b.profilePhotoAbsPath);
  final dateFmt = DateFormat.yMd(b.locale);

  doc.addPage(
    pw.MultiPage(
      theme: theme,
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (ctx) => [
        _header(b, photo, b.l.pdfOverviewTitle),
        pw.SizedBox(height: 16),
        _keyValueTable([
          (b.l.petFieldSpecies, _speciesLabel(b.l, b.pet.species)),
          (b.l.petFieldSex, _sexLabel(b.l, b.pet.sex, b.pet.isNeutered)),
          if (b.pet.breed != null && b.pet.breed!.isNotEmpty)
            (b.l.petFieldBreed, b.pet.breed!),
          if (b.pet.dateOfBirth != null)
            (b.l.petFieldDateOfBirth, dateFmt.format(b.pet.dateOfBirth!)),
          if (b.pet.color != null && b.pet.color!.isNotEmpty)
            (b.l.petFieldColor, b.pet.color!),
          if (b.pet.chipNumber != null && b.pet.chipNumber!.isNotEmpty)
            (b.l.petFieldChipNumber, b.pet.chipNumber!),
          if (b.pet.tassoNumber != null && b.pet.tassoNumber!.isNotEmpty)
            (b.l.petFieldTassoNumber, b.pet.tassoNumber!),
          if (b.latestWeight != null)
            (
              b.l.emergencyWeightTitle,
              '${b.latestWeight!.weightKg.toStringAsFixed(1)} kg (${dateFmt.format(b.latestWeight!.measuredAt)})',
            ),
          if (b.pet.allergies != null && b.pet.allergies!.isNotEmpty)
            (b.l.petFieldAllergies, b.pet.allergies!),
          if (b.pet.notes != null && b.pet.notes!.isNotEmpty)
            (b.l.petFieldNotes, b.pet.notes!),
        ]),
        pw.SizedBox(height: 16),
        if (b.vets.isNotEmpty) ...[
          pw.Text(b.l.vetsListTitle,
              style: pw.TextStyle(
                  fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          _keyValueTable([
            for (final v in b.vets)
              (
                v.name,
                [
                  if (v.practice != null && v.practice!.isNotEmpty)
                    v.practice!,
                  if (v.phone != null && v.phone!.isNotEmpty) v.phone!,
                  if (v.email != null && v.email!.isNotEmpty) v.email!,
                  if (v.address != null && v.address!.isNotEmpty)
                    v.address!,
                ].join(' · '),
              ),
          ]),
          pw.SizedBox(height: 12),
        ],
        if (b.insurances.isNotEmpty) ...[
          pw.Text(b.l.insurancesListTitle,
              style: pw.TextStyle(
                  fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          _keyValueTable([
            for (final i in b.insurances)
              (
                i.provider,
                [
                  if (i.policyNumber != null && i.policyNumber!.isNotEmpty)
                    i.policyNumber!,
                  if (i.contractStart != null)
                    dateFmt.format(i.contractStart!),
                  if (i.contractEnd != null)
                    '→ ${dateFmt.format(i.contractEnd!)}',
                ].join(' · '),
              ),
          ]),
        ],
        _footer(b),
      ],
    ),
  );
  return doc;
}

/// ── Emergency sheet ─────────────────────────────────────────────────────
Future<pw.Document> buildEmergencySheet(PdfBundle b) async {
  final doc = pw.Document();
  final theme = await _loadTheme();
  final photo = await _loadProfileImage(b.profilePhotoAbsPath);
  final dateFmt = DateFormat.yMd(b.locale);

  doc.addPage(
    pw.MultiPage(
      theme: theme,
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (ctx) => [
        _header(b, photo, b.l.pdfEmergencyTitle),
        pw.SizedBox(height: 12),
        if (b.pet.allergies != null && b.pet.allergies!.isNotEmpty)
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.red50,
              border: pw.Border.all(color: PdfColors.red200),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(children: [
              pw.Text('⚠ ',
                  style: const pw.TextStyle(
                      fontSize: 14, color: PdfColors.red800)),
              pw.Expanded(
                child: pw.Text(
                  '${b.l.petFieldAllergies}: ${b.pet.allergies!}',
                  style: const pw.TextStyle(color: PdfColors.red800),
                ),
              ),
            ]),
          ),
        pw.SizedBox(height: 12),
        _keyValueTable([
          if (b.pet.chipNumber != null && b.pet.chipNumber!.isNotEmpty)
            (b.l.petFieldChipNumber, b.pet.chipNumber!),
          if (b.pet.tassoNumber != null && b.pet.tassoNumber!.isNotEmpty)
            (b.l.petFieldTassoNumber, b.pet.tassoNumber!),
          if (b.latestWeight != null)
            (
              b.l.emergencyWeightTitle,
              '${b.latestWeight!.weightKg.toStringAsFixed(1)} kg (${dateFmt.format(b.latestWeight!.measuredAt)})',
            ),
        ]),
        pw.SizedBox(height: 16),
        if (b.vets.isNotEmpty) ...[
          pw.Text(b.l.emergencyVetsSection,
              style: pw.TextStyle(
                  fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          for (final v in b.vets)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(v.name,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  if (v.practice != null && v.practice!.isNotEmpty)
                    pw.Text(v.practice!),
                  if (v.phone != null && v.phone!.isNotEmpty)
                    pw.Text('${b.l.vetFieldPhone}: ${v.phone}'),
                  if (v.email != null && v.email!.isNotEmpty)
                    pw.Text('${b.l.vetFieldEmail}: ${v.email}'),
                  if (v.address != null && v.address!.isNotEmpty)
                    pw.Text('${b.l.vetFieldAddress}: ${v.address}'),
                ],
              ),
            ),
        ],
        _footer(b),
      ],
    ),
  );
  return doc;
}

// ── Shared building blocks ────────────────────────────────────────────────

pw.Widget _header(PdfBundle b, pw.MemoryImage? photo, String docTitle) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.center,
    children: [
      pw.Container(
        width: 60,
        height: 60,
        decoration: pw.BoxDecoration(
          shape: pw.BoxShape.circle,
          color: PdfColors.grey200,
          image: photo == null
              ? null
              : pw.DecorationImage(image: photo, fit: pw.BoxFit.cover),
        ),
      ),
      pw.SizedBox(width: 16),
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(b.pet.name,
                style: pw.TextStyle(
                    fontSize: 22, fontWeight: pw.FontWeight.bold)),
            pw.Text(docTitle,
                style:
                    const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
          ],
        ),
      ),
    ],
  );
}

pw.Widget _footer(PdfBundle b) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(top: 24),
    child: pw.Text(
      '${b.l.appTitle} · ${DateFormat.yMd(b.locale).add_Hm().format(DateTime.now())}',
      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
    ),
  );
}

pw.Widget _keyValueTable(List<(String, String)> rows) {
  return pw.Table(
    columnWidths: const {
      0: pw.FlexColumnWidth(1),
      1: pw.FlexColumnWidth(2),
    },
    children: [
      for (final r in rows)
        pw.TableRow(
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
            ),
          ),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              child: pw.Text(r.$1,
                  style: pw.TextStyle(
                      fontSize: 10, color: PdfColors.grey700)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              child: pw.Text(r.$2, style: const pw.TextStyle(fontSize: 11)),
            ),
          ],
        ),
    ],
  );
}

String _vetName(List<Vet> vets, String? uuid) {
  if (uuid == null) return '—';
  for (final v in vets) {
    if (v.uuid == uuid) return v.name;
  }
  return '—';
}

String _speciesLabel(AppL10n l, Species s) => switch (s) {
      Species.dog => l.speciesDog,
      Species.cat => l.speciesCat,
    };

String _sexLabel(AppL10n l, Sex s, bool neutered) {
  final base = switch (s) {
    Sex.male => l.sexMale,
    Sex.female => l.sexFemale,
  };
  return neutered ? '$base · ${l.sexNeutered}' : base;
}
