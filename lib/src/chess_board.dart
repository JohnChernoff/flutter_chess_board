import 'dart:math';
import 'package:chess_vectors_flutter/chess_vectors_flutter.dart';
import 'package:flutter/material.dart';
import 'package:chess/chess.dart' hide State;
import 'board_arrow.dart';
import 'chess_board_controller.dart';
import 'constants.dart';
import 'dart:ui' as ui;

class ChessBoard extends StatefulWidget {
  /// An instance of [ChessBoardController] which holds the game and allows
  /// manipulating the board programmatically.
  final ChessBoardController controller;

  /// Size of chessboard
  final double size;

  /// A boolean which checks if the user should be allowed to make moves
  final bool enableUserMoves;

  /// The color type of the board
  final BoardColor boardColor;

  final PlayerColor boardOrientation;

  final void Function(String from,String to,String? prom)? onMove;

  final String pieceSet;

  final List<BoardArrow> arrows;

  final ui.Image? backgroundImage;

  final ui.Color dragHighlightColor;

  final bool dummyBoard;

  final bool hidePieces;

  final ui.Color whitePieceColor,blackPieceColor,gridColor;

  const ChessBoard({
    Key? key,
    required this.controller,
    required this.size,
    this.enableUserMoves = true,
    this.boardColor = BoardColor.brown,
    this.dragHighlightColor = Colors.orange,
    this.boardOrientation = PlayerColor.white,
    this.onMove,
    this.arrows = const [],
    this.backgroundImage,
    this.pieceSet = "leipzig",
    this.dummyBoard = false,
    this.blackPieceColor = Colors.black,
    this.whitePieceColor = Colors.white,
    this.gridColor = Colors.grey,
    this.hidePieces = false,
  }) : super(key: key);

  static Image getPieceImage(String style, PieceType? type, Color color, {blendColor = Colors.white}) {
    String path = "$style/${color.name[0].toUpperCase()}${type?.name.toLowerCase() ?? "x"}.png";
    return Image.asset("images/piece_sets/$path", //scale: .9,
      package: 'flutter_chess_board',
      fit: BoxFit.cover,
      colorBlendMode: BlendMode.modulate,
      color: blendColor, //pieceColor == Chess.BLACK ? blackPieceColor : whitePieceColor,
    ); //return AssetImage("${(kDebugMode && kIsWeb)?"":"assets/"}$path");
  }

  @override
  State<ChessBoard> createState() => _ChessBoardState();
}

class _ChessBoardState extends State<ChessBoard> {
  String dragSquare = "";
  String originalDragSquare = "";

  Offset dragAnchorStrategy(Draggable<Object> d, BuildContext context, Offset point) {
    return Offset(widget.size/16,widget.size/16);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Chess>(
      valueListenable: widget.controller,
      builder: (context, game, _) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            children: [
              AspectRatio(
                child: widget.backgroundImage != null ? CustomPaint(painter: BoardPainter(widget.backgroundImage,widget.gridColor)) : _getBoardImage(widget.boardColor),
                aspectRatio: 1.0,
              ),
              widget.hidePieces ? const SizedBox.shrink(): AspectRatio(
                aspectRatio: 1.0,
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 8),
                  itemBuilder: (context, index) {
                    var row = index ~/ 8;
                    var column = index % 8;
                    var boardRank = widget.boardOrientation == PlayerColor.black
                        ? '${row + 1}'
                        : '${(7 - row) + 1}';
                    var boardFile = widget.boardOrientation == PlayerColor.white
                        ? '${files[column]}'
                        : '${files[7 - column]}';

                    var squareName = '$boardFile$boardRank';
                    var pieceOnSquare = game.get(squareName);

                    var boardPiece = BoardPiece(widget,
                      squareName: squareName,
                      game: game,
                      set: widget.pieceSet,
                      highlightColor: dragSquare == squareName ? widget.dragHighlightColor : null,
                      size: originalDragSquare == squareName ? widget.size : null,
                    );

                    BoardPiece feedbackPiece = BoardPiece(widget,
                      squareName: squareName,
                      game: game,
                      set: widget.pieceSet,
                      size: widget.size,
                    );

                    var draggable = game.get(squareName) != null
                        ? Draggable<PieceMoveData>(
                            child: boardPiece,
                            feedback: feedbackPiece,
                            dragAnchorStrategy: dragAnchorStrategy,
                            childWhenDragging: SizedBox(),
                            data: PieceMoveData(
                              squareName: squareName,
                              pieceType:
                                  pieceOnSquare?.type.toUpperCase() ?? 'P',
                              pieceColor: pieceOnSquare?.color ?? Color.WHITE,
                            ),
                          )
                        :  dragSquare == squareName ? Container(color: widget.dragHighlightColor) : Container();

                    var dragTarget =
                        DragTarget<PieceMoveData>(builder: (context, list, _) {
                      return draggable;
                    }, onWillAccept: (pieceMoveData) {
                      return widget.enableUserMoves ? true : false;
                    }, onAccept: (PieceMoveData pieceMoveData) async {
                      // A way to check if move occurred.
                      Color moveColor = game.turn;
                      String? promStr;
                      if (pieceMoveData.pieceType == "P" &&
                          ((pieceMoveData.squareName[1] == "7" &&
                                  squareName[1] == "8" &&
                                  pieceMoveData.pieceColor == Color.WHITE) ||
                              (pieceMoveData.squareName[1] == "2" &&
                                  squareName[1] == "1" &&
                                  pieceMoveData.pieceColor == Color.BLACK))) {
                        promStr = await _promotionDialog(context);
                      }

                      if (!widget.dummyBoard) {
                        if (promStr != null) {
                          widget.controller.makeMoveWithPromotion(
                            from: pieceMoveData.squareName,
                            to: squareName,
                            pieceToPromoteTo: promStr,
                          );
                        }
                        else {
                          widget.controller.makeMove(
                            from: pieceMoveData.squareName,
                            to: squareName,
                          );
                        }
                      }

                      if (game.turn != moveColor || widget.dummyBoard) {
                        widget.onMove?.call(pieceMoveData.squareName,squareName,promStr);
                      }
                    });

                    return dragTarget;
                  },
                  itemCount: 64,
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                ),
              ),
              if (widget.arrows.isNotEmpty)
                IgnorePointer(
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: CustomPaint(
                      child: Container(),
                      painter:
                          _ArrowPainter(widget.arrows, widget.boardOrientation),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Returns the board image
  Image _getBoardImage(BoardColor color) {
    switch (color) {
      case BoardColor.brown:
        return Image.asset(
          "images/brown_board.png",
          package: 'flutter_chess_board',
          fit: BoxFit.cover,
        );
      case BoardColor.darkBrown:
        return Image.asset(
          "images/dark_brown_board.png",
          package: 'flutter_chess_board',
          fit: BoxFit.cover,
        );
      case BoardColor.green:
        return Image.asset(
          "images/green_board.png",
          package: 'flutter_chess_board',
          fit: BoxFit.cover,
        );
      case BoardColor.orange:
        return Image.asset(
          "images/orange_board.png",
          package: 'flutter_chess_board',
          fit: BoxFit.cover,
        );
    }
  }

  /// Show dialog when pawn reaches last square
  Future<String?> _promotionDialog(BuildContext context) async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return new AlertDialog(
          title: new Text('Choose promotion'),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              InkWell(
                child: WhiteQueen(),
                onTap: () {
                  Navigator.of(context).pop("q");
                },
              ),
              InkWell(
                child: WhiteRook(),
                onTap: () {
                  Navigator.of(context).pop("r");
                },
              ),
              InkWell(
                child: WhiteBishop(),
                onTap: () {
                  Navigator.of(context).pop("b");
                },
              ),
              InkWell(
                child: WhiteKnight(),
                onTap: () {
                  Navigator.of(context).pop("n");
                },
              ),
            ],
          ),
        );
      },
    ).then((value) {
      return value;
    });
  }
}

class BoardPiece extends StatelessWidget {
  final ChessBoard chessBoard;
  final String squareName;
  final Chess game;
  final String set;
  final ui.Color? highlightColor;
  final double? size;

  BoardPiece(this.chessBoard,{
    Key? key,
    required this.squareName,
    required this.game,
    required this.set,
    this.highlightColor,
    this.size
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    late Image imageToDisplay;
    Piece? square = game.get(squareName);
    if (square == null) {
      return Container();
    }
    imageToDisplay = ChessBoard.getPieceImage(set,square.type,square.color,blendColor: (square.color) == Color.WHITE ? chessBoard.whitePieceColor : chessBoard.blackPieceColor);
    double? pieceSize = size == null ? null : size!/8;
    //if (pieceSize != null) print("Dragging"); //double? pieceSize = size == null ? null : size/8;

    return Container( //color: Random().nextBool() ? Colors.green : Colors.red,
      width: pieceSize,
      height: pieceSize,
      child: Center(
        child: imageToDisplay,
        ),
    );
  }
}

class PieceMoveData {
  final String squareName;
  final String pieceType;
  final Color pieceColor;

  PieceMoveData({
    required this.squareName,
    required this.pieceType,
    required this.pieceColor,
  });
}

class _ArrowPainter extends CustomPainter {
  List<BoardArrow> arrows;
  PlayerColor boardOrientation;

  _ArrowPainter(this.arrows, this.boardOrientation);

  @override
  void paint(Canvas canvas, Size size) {
    var blockSize = size.width / 8;
    var halfBlockSize = size.width / 16;

    for (var arrow in arrows) {
      var startFile = files.indexOf(arrow.from[0]);
      var startRank = int.parse(arrow.from[1]) - 1;
      var endFile = files.indexOf(arrow.to[0]);
      var endRank = int.parse(arrow.to[1]) - 1;

      int effectiveRowStart = 0;
      int effectiveColumnStart = 0;
      int effectiveRowEnd = 0;
      int effectiveColumnEnd = 0;

      if (boardOrientation == PlayerColor.black) {
        effectiveColumnStart = 7 - startFile;
        effectiveColumnEnd = 7 - endFile;
        effectiveRowStart = startRank;
        effectiveRowEnd = endRank;
      } else {
        effectiveColumnStart = startFile;
        effectiveColumnEnd = endFile;
        effectiveRowStart = 7 - startRank;
        effectiveRowEnd = 7 - endRank;
      }

      var startOffset = Offset(
          ((effectiveColumnStart + 1) * blockSize) - halfBlockSize,
          ((effectiveRowStart + 1) * blockSize) - halfBlockSize);
      var endOffset = Offset(
          ((effectiveColumnEnd + 1) * blockSize) - halfBlockSize,
          ((effectiveRowEnd + 1) * blockSize) - halfBlockSize);

      var yDist = 0.8 * (endOffset.dy - startOffset.dy);
      var xDist = 0.8 * (endOffset.dx - startOffset.dx);

      var paint = Paint()
        ..strokeWidth = halfBlockSize * 0.8
        ..color = arrow.color;

      canvas.drawLine(startOffset,
          Offset(startOffset.dx + xDist, startOffset.dy + yDist), paint);

      var slope =
          (endOffset.dy - startOffset.dy) / (endOffset.dx - startOffset.dx);

      var newLineSlope = -1 / slope;

      var points = _getNewPoints(
          Offset(startOffset.dx + xDist, startOffset.dy + yDist),
          newLineSlope,
          halfBlockSize);
      var newPoint1 = points[0];
      var newPoint2 = points[1];

      var path = Path();

      path.moveTo(endOffset.dx, endOffset.dy);
      path.lineTo(newPoint1.dx, newPoint1.dy);
      path.lineTo(newPoint2.dx, newPoint2.dy);
      path.close();

      canvas.drawPath(path, paint);
    }
  }

  List<Offset> _getNewPoints(Offset start, double slope, double length) {
    if (slope == double.infinity || slope == double.negativeInfinity) {
      return [
        Offset(start.dx, start.dy + length),
        Offset(start.dx, start.dy - length)
      ];
    }

    return [
      Offset(start.dx + (length / sqrt(1 + (slope * slope))),
          start.dy + ((length * slope) / sqrt(1 + (slope * slope)))),
      Offset(start.dx - (length / sqrt(1 + (slope * slope))),
          start.dy - ((length * slope) / sqrt(1 + (slope * slope)))),
    ];
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) {
    return arrows != oldDelegate.arrows;
  }
}

class BoardPainter extends CustomPainter {
  final ui.Image? image;
  final ui.Color gridColor;

  const BoardPainter(this.image,this.gridColor);

  @override
  void paint(Canvas canvas, Size size) { //print("Size: $size");
    ui.Image? boardImage = image;
    if (boardImage != null) {
      canvas.scale(
          size.width / boardImage.width,
          size.height / boardImage.height
      );
      canvas.drawImage(boardImage, const Offset(0, 0), Paint());
      double squareWidth = boardImage.width/8;
      double squareHeight = boardImage.height/8;
      final paint = ui.Paint()
        ..color = gridColor
        ..strokeWidth = 1;
      for (double x=0; x<=boardImage.width; x+= squareWidth) {
        canvas.drawLine(ui.Offset(x, 0), ui.Offset(x, boardImage.height as double), paint);
      }
      for (double y=0; y<=boardImage.height; y+= squareHeight) {
        canvas.drawLine(ui.Offset(0, y), ui.Offset(boardImage.width as double,y), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
