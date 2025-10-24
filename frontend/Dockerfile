FROM node:20-alpine AS build

# Default to true if not provided
ARG REACT_APP_USE_MOCK_DATA=true
ENV REACT_APP_USE_MOCK_DATA=$REACT_APP_USE_MOCK_DATA

# Backend API URL (default to /api for nginx proxy)
ARG REACT_APP_API_BASE_URL=/api
ENV REACT_APP_API_BASE_URL=$REACT_APP_API_BASE_URL

WORKDIR /app

COPY package*.json ./

RUN npm install

COPY . .

RUN echo "Building with REACT_APP_USE_MOCK_DATA=${REACT_APP_USE_MOCK_DATA}"

RUN chmod +x node_modules/.bin/* && npm run build

FROM nginx:alpine

COPY --from=build /app/build /usr/share/nginx/html
COPY nginx.conf /etc/nginx/templates/default.conf.template

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]