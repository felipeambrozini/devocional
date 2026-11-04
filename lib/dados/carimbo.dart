const _umDiaEmMs = 24 * 60 * 60 * 1000;

/// Um carimbo de tempo não pode estar mais de um dia no futuro: um relógio
/// errado em outro aparelho ganharia todas as fusões seguintes.
int limitarCarimboNoFuturo(int emMilissegundos) {
  final teto = DateTime.now().millisecondsSinceEpoch + _umDiaEmMs;
  return emMilissegundos < teto ? emMilissegundos : teto;
}
