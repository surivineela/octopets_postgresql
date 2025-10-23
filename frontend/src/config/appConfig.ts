export interface AppConfig {
    apiUrl: string;
    useMockData: boolean;
}

export const appConfig: AppConfig = {
    // Use environment variable for backend URL, fallback to relative path for nginx proxy
    apiUrl: process.env.REACT_APP_API_BASE_URL || '/api',
    useMockData: process.env.REACT_APP_USE_MOCK_DATA === undefined ? true : process.env.REACT_APP_USE_MOCK_DATA.toLowerCase() === 'true'
};
