import 'package:flutter/material.dart';

import '../controllers/music_search_controller.dart';
import '../models/song.dart';
import '../theme/app_theme.dart';
import '../widgets/song_panel.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({
    super.key,
    required this.controller,
    required this.currentSong,
    required this.isPlaying,
    required this.onPlay,
  });

  final MusicSearchController controller;
  final Song? currentSong;
  final bool isPlaying;
  final ValueChanged<Song> onPlay;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final TextEditingController _textController;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.controller.keyword);
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(28, 42, 28, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onChanged: widget.controller.updateKeyword,
                  onSubmitted: widget.controller.search,
                  style: const TextStyle(color: AppColors.text, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: '搜索歌曲、歌手或专辑',
                    hintStyle: const TextStyle(color: AppColors.faint),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.muted,
                    ),
                    suffixIcon: _textController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: '清空',
                            onPressed: () {
                              _textController.clear();
                              widget.controller.updateKeyword('');
                              setState(() {});
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(vertical: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: _content(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _content() {
    final controller = widget.controller;
    if (controller.hasSearched) {
      return SongPanel(
        title: '搜索结果',
        songs: controller.results,
        currentSong: widget.currentSong,
        isPlaying: widget.isPlaying,
        emptyText: '没有找到相关歌曲',
        onPlay: widget.onPlay,
      );
    }

    if (controller.keyword.trim().isNotEmpty) {
      return _Suggestions(
        songs: controller.suggestions,
        onSelected: (song) {
          _textController.text = song.title;
          _textController.selection = TextSelection.collapsed(
            offset: song.title.length,
          );
          controller.search(song.title);
        },
      );
    }

    return _SearchHistory(
      values: controller.history,
      onSelected: (value) {
        _textController.text = value;
        _textController.selection = TextSelection.collapsed(
          offset: value.length,
        );
        controller.useHistory(value);
      },
      onRemove: controller.removeHistory,
      onClear: controller.clearHistory,
    );
  }
}

class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.songs, required this.onSelected});

  final List<Song> songs;
  final ValueChanged<Song> onSelected;

  @override
  Widget build(BuildContext context) {
    if (songs.isEmpty) {
      return const Center(
        child: Text('暂无联想结果', style: TextStyle(color: AppColors.faint)),
      );
    }

    return ListView.separated(
      itemCount: songs.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final song = songs[index];
        return Material(
          color: Colors.transparent,
          child: ListTile(
            onTap: () => onSelected(song),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            leading: const Icon(Icons.search_rounded, color: AppColors.faint),
            title: Text(
              song.title,
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              '${song.artist} · ${song.album}',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            trailing: const Icon(
              Icons.north_west_rounded,
              color: AppColors.faint,
              size: 17,
            ),
          ),
        );
      },
    );
  }
}

class _SearchHistory extends StatelessWidget {
  const _SearchHistory({
    required this.values,
    required this.onSelected,
    required this.onRemove,
    required this.onClear,
  });

  final List<String> values;
  final ValueChanged<String> onSelected;
  final ValueChanged<String> onRemove;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return const Center(
        child: Text('搜索记录会保存在这里', style: TextStyle(color: AppColors.faint)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '最近搜索',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            TextButton(onPressed: onClear, child: const Text('清空')),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            itemCount: values.length,
            itemBuilder: (context, index) {
              final value = values[index];
              return Material(
                color: Colors.transparent,
                child: ListTile(
                  onTap: () => onSelected(value),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  leading: const Icon(
                    Icons.history_rounded,
                    color: AppColors.faint,
                  ),
                  title: Text(
                    value,
                    style: const TextStyle(color: AppColors.text),
                  ),
                  trailing: IconButton(
                    tooltip: '删除记录',
                    onPressed: () => onRemove(value),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
