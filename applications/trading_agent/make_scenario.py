import csv
import random
import sys

SEED = 11
START_PRICE = 100.0


def generatePath(seed, steps, moveFn):
    """Generates a reproducible path while rounding each observed close."""
    rng = random.Random(seed)
    prices = [START_PRICE]
    for index in range(steps - 1):
        prices.append(round(prices[-1] * (1.0 + moveFn(rng, index, prices[-1])), 2))
    return prices


def generateVshape():
    return generatePath(
        31, 32,
        lambda rng, index, price: rng.gauss(
            0.008 if index < 9 else (-0.018 if index < 19 else 0.012), 0.012
        ),
    )


def generateChoppy():
    return generatePath(
        23, 32,
        lambda rng, index, price: 0.10 * ((START_PRICE - price) / price)
        + rng.gauss(0.0, 0.018),
    )


def generateDowntrend():
    return generatePath(
        29, 32,
        lambda rng, index, price: -0.055 if index == 13 else rng.gauss(-0.008, 0.014),
    )


def generateRealistic():
    """Random walk with three phases: uptrend, crash with panic days, recovery."""
    rng = random.Random(SEED)
    prices = [START_PRICE]

    # Regime 1: gentle uptrend (18 steps), drift +0.5%, noise 1.1%
    for _ in range(18):
        move = rng.gauss(0.005, 0.011)
        prices.append(prices[-1] * (1.0 + move))

    # Regime 2: crash (11 steps), drift -2.2%, noise 1.8%, with two
    # fat-tail panic days injected the way real crashes have them.
    panicSteps = {3: -0.095, 6: -0.12}
    for i in range(11):
        move = panicSteps.get(i, rng.gauss(-0.022, 0.018))
        prices.append(prices[-1] * (1.0 + move))

    # Regime 3: choppy recovery (20 steps), drift +0.9%, noise 1.9%
    for _ in range(20):
        move = rng.gauss(0.009, 0.019)
        prices.append(prices[-1] * (1.0 + move))

    return [round(p, 2) for p in prices]


def readCsvCloses(path, column):
    """Reads the close column from a CSV and scales the first price to 100."""
    closes = []
    with open(path, newline="") as handle:
        for row in csv.DictReader(handle):
            value = row.get(column, "").strip()
            if value:
                closes.append(float(value))
    if not closes:
        raise SystemExit(f"no values found in column '{column}' of {path}")
    scale = START_PRICE / closes[0]
    return [round(c * scale, 2) for c in closes]


def formatScenario(name, prices):
    """Formats a price list as a tradingScenarioPrices equation."""
    joined = " ".join(f"{p}" for p in prices)
    return f"(= (tradingScenarioPrices {name})\n    ({joined})\n)"


def main():
    if len(sys.argv) >= 2 and sys.argv[1] == "generate":
        name = sys.argv[2] if len(sys.argv) > 2 else "realistic"
        generators = {
            "vshape": generateVshape,
            "choppy": generateChoppy,
            "downtrend": generateDowntrend,
            "realistic": generateRealistic,
        }
        if name not in generators:
            raise SystemExit(f"unknown built-in scenario '{name}'")
        print(formatScenario(name, generators[name]()))
    elif len(sys.argv) >= 7 and sys.argv[1] == "walk":
        name = sys.argv[2]
        seed = int(sys.argv[3])
        steps = int(sys.argv[4])
        drift = float(sys.argv[5])
        volatility = float(sys.argv[6])
        prices = generatePath(seed, steps, lambda rng, index, price: rng.gauss(drift, volatility))
        print(formatScenario(name, prices))
    elif len(sys.argv) >= 4 and sys.argv[1] == "csv":
        column = sys.argv[4] if len(sys.argv) > 4 else "Close"
        prices = readCsvCloses(sys.argv[2], column)
        print(formatScenario(sys.argv[3], prices))
    else:
        print(__doc__)
        sys.exit(1)


if __name__ == "__main__":
    main()
