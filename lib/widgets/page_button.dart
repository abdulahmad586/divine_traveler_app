import 'package:flutter/material.dart';
import 'package:quran/quran.dart';

class PageButton extends StatefulWidget {
  final Function(int) onPageChosen;
  final int initialPage;

  PageButton(this.initialPage, this.onPageChosen);

  @override
  State<PageButton> createState() => _PageButtonState();
}

class _PageButtonState extends State<PageButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  static const totalButtonsToLoad = 10;
  late ScrollController scrollController;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    // BUG-14: replaced onAttach (which scrolled to screen width — wrong target)
    // with a post-frame callback that centres on the current page button.
    scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.jumpTo(
            scrollController.position.maxScrollExtent / 2);
      }
    });

    _controller.forward(from: 0.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (BuildContext context, Widget? child) {
        return SingleChildScrollView(
          controller: scrollController,
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = totalButtonsToLoad; i >= 1; i--)
                if (widget.initialPage + i < totalPagesCount)
                  Padding(
                    padding: const EdgeInsets.all(5.0),
                    child: IconButton(
                        onPressed: () {
                          _controller
                              .animateBack(0.0)
                              .then((value) => widget.onPageChosen(widget.initialPage + i));
                        },
                        icon: Text(
                          getVerseEndSymbol(widget.initialPage + i),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold, color: Colors.grey),
                        )),
                  ),
              Padding(
                padding: const EdgeInsets.all(5.0),
                child: IconButton(
                    onPressed: () {
                      _controller
                          .animateBack(0.0)
                          .then((value) => widget.onPageChosen(widget.initialPage));
                    },
                    icon: Text(
                      getVerseEndSymbol(widget.initialPage),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold, color: Colors.green),
                    )),
              ),
              for (int i = 1; i <= totalButtonsToLoad; i++)
                if (widget.initialPage - i > 0)
                  Padding(
                    padding: const EdgeInsets.all(5.0),
                    child: IconButton(
                        onPressed: () {
                          _controller
                              .animateBack(0.0)
                              .then((value) => widget.onPageChosen(widget.initialPage - i));
                        },
                        icon: Text(
                          getVerseEndSymbol(widget.initialPage - i),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold, color: Colors.grey),
                        )),
                  )
            ],
          ),
        );
      },
    );
  }
}
