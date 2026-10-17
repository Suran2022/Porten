/*
 * 业务 API 接口定义（Retrofit）。
 *
 * 路径与后端 routers 注册严格一致（均带 /api/v1 前缀由 baseUrl 承载）：
 *   - /auth/send-verification-code、/auth/register、/auth/login/password、
 *     /auth/login/email-code、/auth/logout
 *   - /schedules、/schedules/related、/schedules/{id}（PATCH）
 *   - /trips、/trips/assistant
 *   - /notes、/notes/{id}（PATCH / DELETE）
 *
 * 约束：
 *   1. 只声明传输，不写业务逻辑；错误统一由 [ApiResponse.unwrap] 解包；
 *   2. 请求体 / 响应体一律使用 :core:model 的可序列化模型（snake_case 已显式标注）。
 */

package jys.porten.core.network

import jys.porten.core.model.AuthLoginCodePayload
import jys.porten.core.model.AuthLoginPasswordPayload
import jys.porten.core.model.AuthLoginResult
import jys.porten.core.model.AuthLogoutPayload
import jys.porten.core.model.AuthRegisterPayload
import jys.porten.core.model.AuthSendCodePayload
import jys.porten.core.model.NoteItem
import jys.porten.core.model.NoteListData
import jys.porten.core.model.NoteUpsertPayload
import jys.porten.core.model.ScheduleCreatePayload
import jys.porten.core.model.ScheduleItem
import jys.porten.core.model.ScheduleListData
import jys.porten.core.model.ScheduleRelatedData
import jys.porten.core.model.ScheduleUpdatePayload
import jys.porten.core.model.TripAssistantCard
import jys.porten.core.model.TripCreatePayload
import jys.porten.core.model.TripItem
import jys.porten.core.model.TripListData
import retrofit2.http.Body
import retrofit2.http.DELETE
import retrofit2.http.GET
import retrofit2.http.PATCH
import retrofit2.http.POST
import retrofit2.http.Path

public interface PortenApiService {

    // ------------------------------------------------------------ 认证

    @POST("auth/send-verification-code")
    public suspend fun sendVerificationCode(
        @Body payload: AuthSendCodePayload,
    ): ApiResponse<Map<String, Boolean>>

    @POST("auth/register")
    public suspend fun register(
        @Body payload: AuthRegisterPayload,
    ): ApiResponse<AuthLoginResult>

    @POST("auth/login/password")
    public suspend fun loginPassword(
        @Body payload: AuthLoginPasswordPayload,
    ): ApiResponse<AuthLoginResult>

    @POST("auth/login/email-code")
    public suspend fun loginEmailCode(
        @Body payload: AuthLoginCodePayload,
    ): ApiResponse<AuthLoginResult>

    @POST("auth/logout")
    public suspend fun logout(
        @Body payload: AuthLogoutPayload,
    ): ApiResponse<Map<String, Boolean>>

    // ------------------------------------------------------------ 我的日程

    @GET("schedules")
    public suspend fun listSchedules(): ApiResponse<ScheduleListData>

    @GET("schedules/related")
    public suspend fun scheduleRelated(): ApiResponse<ScheduleRelatedData>

    @POST("schedules")
    public suspend fun createSchedule(
        @Body payload: ScheduleCreatePayload,
    ): ApiResponse<ScheduleItem>

    @PATCH("schedules/{id}")
    public suspend fun updateSchedule(
        @Path("id") id: Long,
        @Body payload: ScheduleUpdatePayload,
    ): ApiResponse<ScheduleItem>

    // ------------------------------------------------------------ 我的旅程

    @GET("trips")
    public suspend fun listTrips(): ApiResponse<TripListData>

    @GET("trips/assistant")
    public suspend fun tripAssistantCard(): ApiResponse<TripAssistantCard>

    @POST("trips")
    public suspend fun createTrip(
        @Body payload: TripCreatePayload,
    ): ApiResponse<TripItem>

    // ------------------------------------------------------------ 记笔记

    @GET("notes")
    public suspend fun listNotes(): ApiResponse<NoteListData>

    @POST("notes")
    public suspend fun createNote(
        @Body payload: NoteUpsertPayload,
    ): ApiResponse<NoteItem>

    @PATCH("notes/{id}")
    public suspend fun updateNote(
        @Path("id") id: Long,
        @Body payload: NoteUpsertPayload,
    ): ApiResponse<NoteItem>

    @DELETE("notes/{id}")
    public suspend fun deleteNote(@Path("id") id: Long): ApiResponse<Map<String, Boolean>>
}
