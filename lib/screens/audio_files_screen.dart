import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran/quran.dart';
import 'package:tahfeex/model/models.dart';
import 'package:tahfeex/resources/resources.dart';
import 'package:tahfeex/screens/screens.dart';
import 'package:tahfeex/service/states/states.dart';
import 'package:tahfeex/utils/utils.dart';
import 'package:tahfeex/widgets/widgets.dart';

class AudioFilesScreen extends StatelessWidget {
  final int surahNumber;
  const AudioFilesScreen({super.key, required this.surahNumber});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AudioFilesCubit>(
      create: (_) => AudioFilesCubit(surahNumber),
      child: BlocBuilder<AudioFilesCubit, AudioFilesState>(
          builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: Text(getSurahName(surahNumber)),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () async {
              FilePickerResult? result = await FilePicker.platform.pickFiles();

              if (result != null && result.files.single.path != null) {
                if (context.mounted) {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (ct) =>
                              NewAudio(surahNumber, result.files.single,
                                  onSurahAdd: (surahAudio) {
                                if (context.mounted) {
                                  context
                                      .read<AudioFilesCubit>()
                                      .addSurahAudio(surahAudio);
                                }
                              })));
                }

                // File file = File(result.files.single.path!);
                // SurahAudio surahAudio = SurahAudio(audioName: result.files.single.name, surahNumber: surahNumber, surahNameArabic: getSurahNameArabic(surahNumber), surahNameEnglish: getSurahName(surahNumber), totalAyahs: getVerseCount(surahNumber), ayahs: [],localFileUrl: file.path);
                // if(!context.mounted) return;
                // context.read<AudioFilesCubit>().addSurahAudio(surahAudio);
              }
            },
            child: const Icon(Icons.add),
          ),
          body: Container(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Your saved recitations for this surah.",
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        ScholarAudioPicker.show(
                          context,
                          surahNumber: surahNumber,
                          surahNameEnglish: getSurahName(surahNumber),
                          onSelected: (audio) {
                            if (context.mounted) {
                              context
                                  .read<AudioFilesCubit>()
                                  .addSurahAudio(audio);
                            }
                          },
                        );
                      },
                      icon: const Icon(Icons.school_outlined, size: 16),
                      label: const Text("Scholars"),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        CommunityAudioPicker.show(
                          context,
                          surahNumber: surahNumber,
                          surahNameEnglish: getSurahName(surahNumber),
                          onSelected: (audio) {
                            if (context.mounted) {
                              context
                                  .read<AudioFilesCubit>()
                                  .addSurahAudio(audio);
                            }
                          },
                        );
                      },
                      icon: const Icon(Icons.people_outline, size: 16),
                      label: const Text("Community"),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Expanded(
                    child: state.audioFiles == null || state.audioFiles!.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.library_music_outlined,
                                    size: 48, color: Colors.grey[300]),
                                const SizedBox(height: 12),
                                Text(
                                  "No recitations saved yet.",
                                  style: TextStyle(color: Colors.grey[500]),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "Tap + to add from your device, browse scholars, or browse the community.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[400]),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: state.audioFiles!.length,
                            itemBuilder: (c, index) {
                              return AudioFileListItem(state.audioFiles![index],
                                  onTap: () {
                                if (state.audioFiles![index].ayahs.length !=
                                    state.audioFiles![index].totalAyahs) {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (c) => AudioTrainingScreen(
                                                state.audioFiles![index],
                                                onUpdate: (sa) {
                                                  BlocProvider.of<
                                                              AudioFilesCubit>(
                                                          context)
                                                      .updateSurahAudio(
                                                          sa, index);
                                                },
                                              )));
                                } else {
                                  AlertUtls.toast(context,
                                      message: "Verses are complete");
                                }
                              }, trailing: Builder(builder: (ctx) {
                                final audio = state.audioFiles![index];
                                final complete =
                                    audio.ayahs.length == audio.totalAyahs;
                                final alreadyUploaded =
                                    audio.driveFileId != null;
                                final options = [
                                  if (complete && !alreadyUploaded)
                                    'Share with community',
                                  if (complete && alreadyUploaded)
                                    'Re-upload to community',
                                  'Delete record',
                                  'Delete file',
                                ];
                                return MorePopup(
                                  options: options,
                                  onAction: (i) async {
                                    final label = options[i];
                                    if (label == 'Share with community' ||
                                        label == 'Re-upload to community') {
                                      if (context.mounted) {
                                        UploadProgressSheet.show(
                                          context,
                                          surahAudio: audio,
                                          onSuccess: (result) {
                                            audio.driveFileId =
                                                result.audioFileId;
                                            audio.driveTimingFileId =
                                                result.timingFileId;
                                            audio.remoteFileUrl =
                                                result.audioPublicUrl;
                                            BlocProvider.of<AudioFilesCubit>(
                                                    context)
                                                .updateSurahAudio(audio, index);
                                          },
                                        );
                                      }
                                    } else if (label == 'Delete record') {
                                      BlocProvider.of<AudioFilesCubit>(context)
                                          .removeSurahAudio(index);
                                    } else if (label == 'Delete file') {
                                      final filePath = audio.localFileUrl;
                                      if (filePath != null) {
                                        final file = File(filePath);
                                        if (await file.exists()) {
                                          await file.delete();
                                        }
                                      }
                                      if (context.mounted) {
                                        BlocProvider.of<AudioFilesCubit>(
                                                context)
                                            .removeSurahAudio(index);
                                      }
                                    }
                                  },
                                );
                              }));
                            })),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class AudioFileListItem extends StatelessWidget {
  final SurahAudio audioFile;
  final VoidCallback? onTap;
  final Widget? trailing;

  const AudioFileListItem(this.audioFile,
      {super.key, this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    final bool complete = audioFile.totalAyahs == audioFile.ayahs.length;
    final double progress = audioFile.totalAyahs > 0
        ? audioFile.ayahs.length / audioFile.totalAyahs
        : 0.0;

    final isCommunity = audioFile.contributionId != null;
    final isScholar = audioFile.verified && audioFile.contributionId == null;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: IconButton.filledTonal(
        icon: Icon(
          isCommunity
              ? Icons.people_outline
              : isScholar
                  ? Icons.school_outlined
                  : Icons.music_note,
          color: isCommunity || isScholar ? AppColors.primaryColor : null,
        ),
        onPressed: () {},
      ),
      trailing: trailing,
      title: Row(
        children: [
          Expanded(
            child: Text(
              audioFile.reciterName.isNotEmpty
                  ? audioFile.reciterName
                  : audioFile.audioName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isCommunity)
            Container(
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Community',
                style: TextStyle(
                    fontSize: 10,
                    color: AppColors.primaryColor,
                    fontWeight: FontWeight.w600),
              ),
            ),
          if (isScholar)
            Container(
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Scholar',
                style: TextStyle(
                    fontSize: 10,
                    color: Colors.teal,
                    fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isCommunity && audioFile.createdByName != null)
            Text(
              'by ${audioFile.createdByName}',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          if (complete) ...[
            const Row(children: [
              Icon(Icons.check_circle, color: Colors.green, size: 14),
              SizedBox(width: 4),
              Text("All verses synced",
                  style: TextStyle(color: Colors.green, fontSize: 12)),
            ]),
            if (!isCommunity && audioFile.driveFileId != null)
              const Row(children: [
                SizedBox(width: 2),
                Icon(Icons.cloud_done, color: Colors.blue, size: 14),
                SizedBox(width: 4),
                Text("Shared with community",
                    style: TextStyle(color: Colors.blue, fontSize: 12)),
              ]),
          ] else ...[
            Text(
              "${audioFile.ayahs.length}/${audioFile.totalAyahs} verses synced",
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[200],
                color: Colors.green,
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 3),
            const Text(
              "Tap to resume sync →",
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.green,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ],
      ),
      onTap: onTap,
    );
  }
}
