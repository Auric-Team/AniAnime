/**
 * MAL & Anilist Metadata Service
 * Provides 1000% accurate anime metadata using multiple sources
 */

import axios, { AxiosInstance } from 'axios';

// GraphQL endpoint for Anilist
const ANILIST_API = 'https://graphql.anilist.co';
const MAL_API = 'https://api.myanimelist.net/v2';
const JIKAN_API = 'https://api.jikan.moe/v4';

export interface MALInfo {
  malId: number;
  title: string;
  synopsis?: string;
  type?: string;
  episodes?: number;
  status?: string;
  aired?: string;
  duration?: string;
  rating?: string;
  score?: number;
  rank?: number;
  popularity?: number;
  members?: number;
  favorites?: number;
  genres?: string[];
  studios?: string[];
  source?: string;
  season?: string;
  year?: number;
  images?: {
    jpg?: { image_url?: string; large_image_url?: string };
    webp?: { image_url?: string; large_image_url?: string };
  };
  trailer?: {
    youtube_id?: string;
    url?: string;
  };
}

export interface AnilistInfo {
  anilistId: number;
  malId?: number;
  title: {
    romaji?: string;
    english?: string;
    native?: string;
  };
  description?: string;
  type?: string;
  episodes?: number;
  status?: string;
  duration?: number;
  genres?: string[];
  tags?: { name: string; rank: number }[];
  averageScore?: number;
  meanScore?: number;
  popularity?: number;
  favourites?: number;
  season?: string;
  seasonYear?: number;
  startDate?: { year?: number; month?: number; day?: number };
  endDate?: { year?: number; month?: number; day?: number };
  coverImage?: {
    extraLarge?: string;
    large?: string;
    medium?: string;
  };
  bannerImage?: string;
  trailer?: {
    id?: string;
    site?: string;
  };
  studios?: { nodes: { name: string }[] };
  source?: string;
  hashtag?: string;
  siteUrl?: string;
}

export interface UnifiedMetadata {
  malId?: number;
  anilistId?: number;
  title: {
    english?: string;
    romaji?: string;
    native?: string;
  };
  description?: string;
  synopsis?: string;
  type?: string;
  episodes?: number;
  status?: string;
  duration?: string;
  rating?: string;
  score?: number;
  rank?: number;
  popularity?: number;
  genres?: string[];
  studios?: string[];
  source?: string;
  season?: string;
  year?: number;
  aired?: string;
  images?: {
    poster?: string;
    banner?: string;
  };
  trailer?: {
    youtubeId?: string;
    url?: string;
  };
}

export class MetadataService {
  private axios: AxiosInstance;

  constructor() {
    this.axios = axios.create({
      headers: {
