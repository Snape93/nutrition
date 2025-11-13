import joblib
import sys
from pprint import pprint

path = r'Nutrition/model/best_regression_model.joblib'
try:
    model = joblib.load(path)
except Exception as e:
    print('LOAD_ERROR:', e)
    sys.exit(1)

print('MODEL_TYPE:', type(model).__name__)

try:
    from sklearn.pipeline import Pipeline
    if isinstance(model, Pipeline):
        print('PIPELINE_STEPS:')
        for name, step in model.steps:
            print(f'  - {name}: {type(step).__name__}')
except Exception as e:
    print('PIPELINE_CHECK_ERROR:', e)

try:
    print('N_FEATURES_IN:', getattr(model, 'n_features_in_', 'NA'))
except Exception as e:
    print('N_FEATURES_IN_ERROR:', e)

feature_names = None
for attr in ('feature_names_in_', 'get_feature_names_out', 'get_feature_names'):
    if hasattr(model, attr):
        try:
            if attr == 'feature_names_in_':
                feature_names = list(getattr(model, attr))
            else:
                feature_names = list(getattr(model, attr)())
            break
        except Exception:
            pass

if feature_names is not None:
    print('FEATURE_NAMES:', '|'.join(map(str, feature_names)))
else:
    print('FEATURE_NAMES: NA')

try:
    from sklearn.compose import ColumnTransformer
    from sklearn.pipeline import Pipeline
    pipe = model if isinstance(model, Pipeline) else None
    if pipe:
        for name, step in pipe.steps:
            if isinstance(step, ColumnTransformer):
                print('COLUMN_TRANSFORMER:', name)
                for tname, trans, cols in step.transformers_:
                    cname = type(trans).__name__ if trans is not None else 'drop'
                    print(f'  - {tname}: {cname} on {cols}')
except Exception as e:
    print('COLUMN_TRANSFORMER_ERROR:', e)
