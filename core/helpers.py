import numpy as np
 
def list_difference(arr1, arr2):
    a = np.asarray(arr1, dtype=float)
    b = np.asarray(arr2, dtype=float)

    if a.shape != b.shape:
        raise ValueError("arr1 and arr2 must have the same shape")
     
    return (a - b).tolist()

def norm(arr):
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


# --- array operations ---

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


# --- additional helper functions ---

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

def index(arr, i):
    return float(np.asarray(arr)[int(i)])

def clip(value, min_val, max_val):
    return float(np.clip(value, min_val, max_val))

def exp(value):
    return float(np.exp(value))

def abs(value):
    return float(np.abs(value))