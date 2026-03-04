import { configureStore } from '@reduxjs/toolkit';
import AuthSlice from './AuthSlice';
import storage from 'redux-persist/lib/storage';
import { persistReducer, persistStore } from 'redux-persist';

// Persist configuration
const persistConfig = {
  key: 'root',
  storage,
};

// Wrapping AuthSlice with persistReducer
const Reducer = persistReducer(persistConfig, AuthSlice);

// Configuring the store
export const store = configureStore({
  reducer: {
    Auth: Reducer,
  },
  middleware: (getDefaultMiddleware) =>
    getDefaultMiddleware({
      serializableCheck: {
        ignoredActions: ['persist/PERSIST', 'persist/REHYDRATE'],
      },
    }),
});

// Persistor instance
export const persistor = persistStore(store);
