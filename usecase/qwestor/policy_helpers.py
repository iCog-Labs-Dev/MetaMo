import math
from collections.abc import Sequence


def project_goals_with_floors(
    goals: Sequence[float],
    floor_indices: Sequence[int],
    floor_values: Sequence[float],
    goal_norm_max: float,
) -> list[float]:
    """Project unit goals into the configured floor-and-norm safe region."""
    projected = [max(0.0, min(1.0, float(value))) for value in goals]
    indices = [int(index) for index in floor_indices]
    floors = [max(0.0, min(1.0, float(value))) for value in floor_values]
    if len(indices) != len(floors):
        raise ValueError("floor indices and values must have equal lengths")
    for index, floor in zip(indices, floors):
        projected[index] = max(projected[index], floor)
    limit = max(0.0, float(goal_norm_max))
    if math.sqrt(sum(value * value for value in projected)) <= limit:
        return projected
    protected = set(indices)
    fixedNormSquared = sum(floor * floor for floor in floors)
    remainingLimit = math.sqrt(max(0.0, limit * limit - fixedNormSquared))
    remainingNorm = math.sqrt(
        sum(
            value * value
            for index, value in enumerate(projected)
            if index not in protected
        )
    )
    scale = min(1.0, remainingLimit / remainingNorm) if remainingNorm else 1.0
    for index, value in enumerate(projected):
        if index in protected:
            projected[index] = floors[indices.index(index)]
        else:
            projected[index] = value * scale
    return projected


def signed_safe_distance(
    goals: Sequence[float],
    modulators: Sequence[float],
    floor_indices: Sequence[int],
    floor_values: Sequence[float],
    goal_norm_max: float,
    threshold_index: int,
    threshold_minimum: float,
    threshold_maximum: float,
    arousal_index: int,
    arousal_minimum: float,
    arousal_maximum: float,
) -> float:
    """Return the smallest signed distance to any Qwestor safe-region bound."""
    goalValues = [float(value) for value in goals]
    modulatorValues = [float(value) for value in modulators]
    distances = [
        goalValues[int(index)] - float(floor)
        for index, floor in zip(floor_indices, floor_values)
    ]
    distances.append(
        float(goal_norm_max)
        - math.sqrt(sum(value * value for value in goalValues))
    )
    threshold = modulatorValues[int(threshold_index)]
    arousal = modulatorValues[int(arousal_index)]
    distances.extend(
        [
            threshold - float(threshold_minimum),
            float(threshold_maximum) - threshold,
            arousal - float(arousal_minimum),
            float(arousal_maximum) - arousal,
        ]
    )
    return min(distances)
