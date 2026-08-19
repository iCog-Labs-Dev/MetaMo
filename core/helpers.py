import numpy as np


def list_difference(arr1, arr2):
    a = np.asarray(arr1, dtype=float)
    b = np.asarray(arr2, dtype=float)

    if a.shape != b.shape:
        raise ValueError("arr1 and arr2 must have the same shape")

    return (a - b).tolist()


def vector_norm(arr):
    return float(np.linalg.norm(arr))


def calculate_norm_difference(arr1, arr2):
    a = np.asarray(arr1, dtype=float)
    b = np.asarray(arr2, dtype=float)

    if a.shape != b.shape:
        raise ValueError("arr1 and arr2 must have the same shape")
    return float(np.sum(np.square(a - b)))


def normalize_vector(arr):
    a = np.asarray(arr)
    n = np.linalg.norm(a)
    return (a / n).tolist() if n > 0 else a.tolist()


# Array Operations


def split(arr, indices_or_sections):
    res = np.split(np.asarray(arr), indices_or_sections)
    return [x.tolist() for x in res]


def sum_array(arr):
    return float(np.sum(arr))


def prod_array(arr):
    return float(np.prod(arr))


def mean_array(arr):
    return float(np.mean(arr))


def std_array(arr):
    return round(float(np.std(arr)), 2)


def var_array(arr):
    return float(np.var(arr))


def dot_array(arr1, arr2):
    a = np.asarray(arr1)
    b = np.asarray(arr2)

    if a.shape != b.shape:
        raise ValueError("arr1 and arr2 must have the same shape")

    return float(np.dot(a, b))


# Additional Helper Functions


def vector_add(arr1, arr2):
    a = np.asarray(arr1, dtype=float)
    b = np.asarray(arr2, dtype=float)

    if a.shape != b.shape:
        raise ValueError("arr1 and arr2 must have the same shape")

    return np.round(a + b, 8).tolist()


def average_arrays(arr1, arr2):
    a = np.asarray(arr1, dtype=float)
    b = np.asarray(arr2, dtype=float)

    if a.shape != b.shape:
        raise ValueError("arr1 and arr2 must have the same shape")

    return ((a + b) / 2.0).tolist()


def clip_vector(arr, min_value=0.0, max_value=1.0):
    return np.clip(np.asarray(arr, dtype=float), min_value, max_value).tolist()


def matrix_is_square(matrix):
    m = np.asarray(matrix, dtype=float)
    return str(m.ndim == 2 and m.shape[0] == m.shape[1]).lower()


def matrix_vector_dot(matrix, vector):
    m = np.asarray(matrix, dtype=float)
    v = np.asarray(vector, dtype=float)

    if m.ndim != 2:
        raise ValueError("matrix must be 2D")
    if m.shape[1] != v.shape[0]:
        raise ValueError("matrix columns must match vector length")

    return np.dot(m, v).tolist()


def abs_number(value):
    return abs(float(value))


def exp_number(value):
    return float(np.exp(float(value)))


def sigmoid_number(value):
    x = float(value)
    return float(1.0 / (1.0 + np.exp(-x)))


def probe_vector(delta, step=0.01, threshold=1e-6):
    d = np.asarray(delta, dtype=float)
    probe = np.where(np.abs(d) > threshold, np.sign(d) * step, step)
    return probe.tolist()


def weighted_average_arrays(arr1, arr2, weight1, weight2):
    a = np.asarray(arr1, dtype=float)
    b = np.asarray(arr2, dtype=float)
    total_weight = float(weight1) + float(weight2)

    if np.isclose(total_weight, 0.0):
        return (a + b) / 2.0

    return ((a * float(weight1)) + (b * float(weight2))) / total_weight


def parallel_merge_goals(
    goals_a,
    goals_b,
    coherence_correction,
    weight_idx,
    safety_idx,
    exploratory_idx,
    social_idx,
):
    """Merge two goal vectors using parameterized index categories."""
    ga = np.asarray(goals_a, dtype=float)
    gb = np.asarray(goals_b, dtype=float)

    if ga.shape != gb.shape:
        raise ValueError("goal vectors must have the same shape")

    w_idx = int(weight_idx)
    weight_a = ga[w_idx]
    weight_b = gb[w_idx]

    base_g = weighted_average_arrays(ga, gb, weight_a, weight_b)
    disagreement_g = np.abs(ga - gb)
    consensus_g = base_g.copy()

    safe_idx = np.array([int(i) for i in safety_idx])
    expl_idx = np.array([int(i) for i in exploratory_idx])
    soc_idx = np.array([int(i) for i in social_idx])

    consensus_g[safe_idx] = np.maximum(ga[safe_idx], gb[safe_idx])
    consensus_g[expl_idx] = np.minimum(ga[expl_idx], gb[expl_idx])
    for si in soc_idx:
        consensus_g[si] = min(base_g[si], ga[si], gb[si])

    goal_correction_scale = np.ones_like(base_g)
    goal_correction_scale[safe_idx] = 1.5
    goal_correction_scale[expl_idx] = 1.0
    for si in soc_idx:
        goal_correction_scale[si] = 0.8

    goal_correction = np.clip(
        coherence_correction * disagreement_g * goal_correction_scale, 0.0, 1.0
    )
    merged_g = base_g + goal_correction * (consensus_g - base_g)
    return merged_g.tolist()


def parallel_merge_modulators(
    mod_a,
    mod_b,
    goals_a,
    goals_b,
    coherence_correction,
    weight_idx,
    caution_idx,
    exploratory_idx,
    shared_idx,
):
    """Merge two modulator vectors using parameterized index categories."""
    ma = np.asarray(mod_a, dtype=float)
    mb = np.asarray(mod_b, dtype=float)
    ga = np.asarray(goals_a, dtype=float)
    gb = np.asarray(goals_b, dtype=float)

    if ma.shape != mb.shape:
        raise ValueError("modulator vectors must have the same shape")

    w_idx = int(weight_idx)
    weight_a = ga[w_idx]
    weight_b = gb[w_idx]

    base_m = weighted_average_arrays(ma, mb, weight_a, weight_b)
    disagreement_m = np.abs(ma - mb)
    consensus_m = base_m.copy()

    caut_idx = np.array([int(i) for i in caution_idx])
    expl_idx = np.array([int(i) for i in exploratory_idx])
    shar_idx = np.array([int(i) for i in shared_idx])

    consensus_m[caut_idx] = np.maximum(ma[caut_idx], mb[caut_idx])
    consensus_m[expl_idx] = np.minimum(ma[expl_idx], mb[expl_idx])
    consensus_m[shar_idx] = (ma[shar_idx] + mb[shar_idx]) / 2.0

    mod_correction_scale = np.ones_like(base_m)
    mod_correction_scale[caut_idx] = 1.5
    mod_correction_scale[expl_idx] = 1.0
    mod_correction_scale[shar_idx] = 0.8

    mod_correction = np.clip(
        coherence_correction * disagreement_m * mod_correction_scale, 0.0, 1.0
    )
    merged_m = base_m + mod_correction * (consensus_m - base_m)
    return merged_m.tolist()


def softmax(arr):
    a = np.asarray(arr)
    exp_a = np.exp(a - np.max(a))

    sum_exp = exp_a.sum()
    if sum_exp == 0:
        return []
    # no round
    return (exp_a / sum_exp).tolist()


def round_number(value, digits=0):
    return round(float(value), digits)


def round_list(arr, digits=0):
    return [round(float(x), digits) for x in arr]


def positive_part(value):
    """max(0.0, value)"""
    return max(0.0, float(value))


def mean_at_indices(arr, indices):
    """Mean of array values at the given indices"""
    vals = [float(arr[int(i)]) for i in indices]
    return float(np.mean(vals)) if vals else 0.0


def project_goals_to_safe(goals, weight_idx, theta_safe, g_max):
    """Project goals into safe region: ensure goals[weight_idx] >= theta_safe and ||goals|| <= g_max."""
    g = np.asarray(goals, dtype=float).copy()
    w = int(weight_idx)
    g[w] = max(g[w], float(theta_safe))
    other_idx = [i for i in range(len(g)) if i != w]
    other_goals = g[other_idx]
    other_norm = np.linalg.norm(other_goals)
    max_other_norm = np.sqrt(max(0.0, float(g_max) ** 2 - g[w] ** 2))
    if other_norm > max_other_norm and other_norm > 0.0:
        g[other_idx] = other_goals * (max_other_norm / other_norm)
    return g.tolist()


def boost_at_indices(arr, indices, boost, max_val=1.0):
    """Add boost to values at given indices, capped at max_val."""
    result = [float(x) for x in arr]
    for idx in indices:
        i = int(idx)
        result[i] = min(float(max_val), result[i] + float(boost))
    return result


def blend_arrays(arr1, arr2, alpha):
    """Linear blend: (1-alpha)*arr1 + alpha*arr2."""
    a = np.asarray(arr1, dtype=float)
    b = np.asarray(arr2, dtype=float)
    return np.round((1.0 - float(alpha)) * a + float(alpha) * b, 8).tolist()


def scale_array(arr, factor):
    """Multiply each element by factor."""
    return np.round(np.asarray(arr, dtype=float) * float(factor), 8).tolist()


def npClip(value, smallest, largest):
    return float(np.clip(value, smallest, largest))

def identity_matrix(n):
    """Returns an nxn identity matrix as a list of lists."""
    return np.eye(int(n)).tolist()


# OpenPsi fuzzy membership primitives

def fuzzy_equal(x, t, alpha):
    """eq. (2): 1 / (1 + alpha*(x-t)^2). Peaks at x==t, decays otherwise."""
    x = float(x)
    t = float(t)
    alpha = float(alpha)
    return float(1.0 / (1.0 + alpha * (x - t) ** 2))


def fuzzy_low(x, t, alpha):
    """eq. (16): fuzzy_equal(x,t,alpha) if x > t, else 1.0 (full 'low' membership at/below t)."""
    x = float(x)
    if x > float(t):
        return fuzzy_equal(x, t, alpha)
    return 1.0


def fuzzy_high(x, t, alpha):
    """eq. (17): fuzzy_equal(x,t,alpha) if x < t, else 1.0 (full 'high' membership at/above t)."""
    x = float(x)
    if x < float(t):
        return fuzzy_equal(x, t, alpha)
    return 1.0