function rdoea()

 clc;format compact;tic;

inputName = 'kodak24\kodim24.png';
% inputName = 'DIV2K_valid_HR\0812.png';
outputName = '01.jpg';
CELL_SIZE = 8; %greater than 5
img = imread(inputName);
%%% MAPPER RGB -> YCbCr
ycbcr_img = rgb2ycbcr(img);
y_image =ycbcr_img(:, :, 1);

%%% Turn into cells 8x8
repeat_height = size(y_image, 1)/CELL_SIZE;
repeat_width = size(y_image, 2)/CELL_SIZE;
repeat_height_mat = repmat(CELL_SIZE, [1 repeat_height]);
repeat_width_mat = repmat(CELL_SIZE, [1 repeat_width]);
y_sub_image = mat2cell(y_image, repeat_height_mat, repeat_width_mat);
y_sub_dct = y_sub_image;
for i=1:repeat_height
    for j=1:repeat_width
        y_sub_image{i, j} = dcTransform(y_sub_image{i, j});
        y_sub_dct{i,j} = getDCT(y_sub_image{i,j});
    end
end

hist_out = GetInvCoffHist(y_sub_dct, repeat_height, repeat_width);
mse_table = estBlockDistortionInd(hist_out);
rate_table = estBlockRateInd(hist_out, repeat_height, repeat_width);

% ---��ʼ��/�����趨
generations=30;                                %��������
popnum=16;                                     %��Ⱥ��С(��Ϊż��)
global poplength;
poplength=64;                                            %���峤��
lumMat = [
    16 11 10 16 24 40 51 61 ...
    12 12 14 19 26 58 60 55 ...
    14 13 16 24 40 57 69 56 ...
    14 17 22 29 51 87 80 62 ...
    18 22 37 56 68 109 103 77 ...
    24 35 55 64 81 104 113 92 ...
    49 64 78 87 103 121 120 101 ...
    72 92 95 98 112 100 103 99];
populationlum = ones(popnum,64);
for i = 1:popnum
   %   out = quantLumMat(lumMat, i);
    out = quantLumMat(lumMat, (50 - ((i) - popnum/2)*5));
    populationlum(i,:) = out;
end


for gene=1:generations                      %��ʼ����

    px=size(populationlum,1);
    if mod(px,2)~=0
        populationlum(px+1,:)=lumMat;
    end
    newpopulation=ones(size(populationlum,1),poplength);
    for i = 1:2:px-1
        a=rand();
        if(a<=0.2)
            cpoint = 20;
            index = getTopKPostion(mse_table, rate_table, populationlum(i,:), populationlum(i+1,:), cpoint);
            newpopulation(i,:) = populationlum(i,:);
            newpopulation(i, index) = populationlum(i+1, index);
            index = getTopKPostion(mse_table, rate_table, populationlum(i+1,:), populationlum(i,:), cpoint);
            newpopulation(i+1,:) = populationlum(i+1,:);
            newpopulation(i+1, index) = populationlum(i, index);              %����
        else
            b=rand();
            if b<=0.5
                if gene<generations/2
                   temp =round(rand.*63)+1;
                else
                    temp =16;
                end
                newpopulation(i,:) = populationlum(i,:);
                newpopulation(i+1,:) = populationlum(i+1,:);
                %            [add_index, minus_index] = getTopKPostionForMut(mse_table, rate_table, populationlum(i,:), temp);%lp
                [ minus_index,index_new] = getTopKPostionForMut(mse_table, rate_table, populationlum(i,:), temp);
                populationlum(i,index_new(1,:)) = minus_index(1,index_new(1,:));
                [ minus_index,index_new] = getTopKPostionForMut(mse_table, rate_table, populationlum(i+1,:), temp);
                populationlum(i+1,index_new(1,:)) = minus_index(1,index_new(1,:));
            else
                newpopulation(i,:) = populationlum(i,:);              %�����
                newpopulation(i+1,:) = populationlum(i+1,:);
                q=round(rand.*100)+1;
                if q<1
                    q=1;
                    scale=50*100/q;
                end
                if q>100
                    q=100;
                    scale=200-q*2;
                end
                if q<50
                    scale=50*100/q;
                else
                    scale=200-q*2;
                end
                for j=1:64
                    newpopulation(i,j)=round((newpopulation(i,j)*scale+50)/100);
                    if newpopulation(i,j)<1
                        newpopulation(i,j)=1;
                    else
                        if newpopulation(i,j)>255
                            newpopulation(i,j)=255;
                        end
                    end
                end
                for k=1:64
                    newpopulation(i+1,k)=round((newpopulation(i+1,k)*scale+50)/100);
                    if newpopulation(i+1,k)<1
                        newpopulation(i+1,k)=1;
                    else
                        if newpopulation(i+1,k)>255
                            newpopulation(i+1,k)=255;
                        end
                    end
                end
            end
        end
    end
    newpopulation=[populationlum;newpopulation];                               
  functionvalue=MSE(newpopulation, y_sub_image, y_sub_dct, repeat_height, repeat_width, outputName, 1, mse_table, rate_table);

    [frontvalue, ~] = NDSort(functionvalue, inf);

    newnum=numel(frontvalue,frontvalue<=1);                            
    if(newnum <50)
        populationlum(1:newnum,:)=newpopulation(frontvalue<=1,:);
    else
        populationlum_temp(1:newnum,:)=newpopulation(frontvalue<=1,:);
        % convex hull
        point = functionvalue(frontvalue<=1,:);
        point(newnum + 1,:)=[point(1,1)+10, point(size(point,1),2)+10];
        [point, index]=unique( point,'rows');
        populationlum_temp_new(1:size(index,1)-1,:)= populationlum_temp(index(1:size(index,1)-1),:);
        dt = delaunayTriangulation(point(:,1),point(:,2));
        k = convexHull(dt); 
        functionvalue_gen = [dt.Points(k,1) dt.Points(k,2)];   
        populationlum = populationlum_temp(1,:);
        populationlum(1:size(k,1)-2,:) = populationlum_temp_new(k(k(1:size(k,1)-1,1)<size(dt.Points,1)),:);
        functionvalue_gen_new = functionvalue_gen(1:size(functionvalue_gen(:,1))-2,:);
        n=size(k,1)-1;
      if gene<20
          for r =1:(size(functionvalue_gen,1)-3)
              c= (functionvalue_gen(r+1,1)- functionvalue_gen(r,1)).^2+(functionvalue_gen(r+1,2)- functionvalue_gen(r,2)).^2;
              if c>15        
                  popolationlum_new= populationlum(r+1,:);
                  ratelow = functionvalue_gen(r+1,1);
                  ratehigh = functionvalue_gen(r,1);
                  quality = 50 - (ratelow - ratehigh)*50/ratelow
                   populationlum(n,:)=quantLumMat(popolationlum_new, quality);  
                   n = n+1;%5.6�޸�
              end     
          end
      end
    end
    

end
% ---�������
output=sortrows(functionvalue(frontvalue==1,:)); %���ս��:��Ⱥ�з�֧���ĺ���ֵ

 paretoindex = frontvalue == 1;  
 paretopopulation = newpopulation(paretoindex,:);

fprintf('�����,��ʱ%4s��\n',num2str(toc));          %�������պ�ʱ

truevalue = MSE(paretopopulation, y_sub_image, y_sub_dct, repeat_height, repeat_width, outputName, 0, mse_table, rate_table);
truevalue_new = sortrows(truevalue); 
figure;
plot(output(:,1),output(:,2),'-*b');
hold on;
plot(truevalue_new(:,1),truevalue_new(:,2),'-*g');
xlabel('Rate(bpp)');ylabel('MSE');
legend('estimate','real');
end


function out = getTopKPostion(mse_whole, rate_whole, lumMat1, lumMat2, k)
value = zeros(64,1);
value(:) = 10000000;
for i = 1:64
   m = floor((i-1)/8)+1;
    n = mod(i-1, 8) + 1;
    q1 = lumMat1(i);
    q2 = lumMat2(i);
    if q1 ~= q2
        if q1 < q2
            dist1 = mse_whole(m,n,q1);
            dist2 = mse_whole(m,n,q2);
            rate1 = rate_whole(m,n,q1);
            rate2 = rate_whole(m,n,q2);
            if rate1 ~= rate2
                slope = (dist2 - dist1)/(rate1 - rate2); %smaller better
                value(i) = slope;
            end
        else
            dist1 = mse_whole(m,n,q1);
            dist2 = mse_whole(m,n,q2);
            rate1 = rate_whole(m,n,q1);
            rate2 = rate_whole(m,n,q2);
            if dist1 ~= dist2
                slope = (rate2 - rate1)/(dist1 - dist2); %smaller better
                value(i) = slope;
            end
        end
    end
end

[x, index]=sort(value);
out = index(1:k);
end

function [ minus_index,index_new] = getTopKPostionForMut(mse_whole, rate_whole, lumMat1, k)
 minus_value = zeros(1,64);
 minus_index = zeros(1,64);
 for i = 1:64
     value(1:255) = 0;
     m = floor((i-1)/8)+1;
     n = mod(i-1, 8) + 1;
     q1 = lumMat1(i); 
     q2 = q1 + 1;
     if q1 < 205&&q1>50
         q_high=q1+50;
         for j=q2:q_high
             if q1 < q2
                 dist1 = mse_whole(m,n,q1);
                 dist2 = mse_whole(m,n,j);
                 rate1 = rate_whole(m,n,q1);
                 rate2 = rate_whole(m,n,j);
                 if dist2~=dist1
                     slope = (rate2 - rate1)/(dist1 - dist2); %bigger better
                     value(j) = slope;
                 end
             end
         end
     else
         if q1>205
             for j=q2:255
                 if q1 < q2
                     dist1 = mse_whole(m,n,q1);
                     dist2 = mse_whole(m,n,j);
                     rate1 = rate_whole(m,n,q1);
                     rate2 = rate_whole(m,n,j);
                     if dist2~=dist1
                         slope = (rate2 - rate1)/(dist1 - dist2); %bigger better
                         value(j) = slope;
                     end
                 end
             end
         else
             if q1<50
                 for j=q2:(q1+50)
                     if q1 < q2
                         dist1 = mse_whole(m,n,q1);
                         dist2 = mse_whole(m,n,j);
                         rate1 = rate_whole(m,n,q1);
                         rate2 = rate_whole(m,n,j);
                         if dist2~=dist1
                             slope = (rate2 - rate1)/(dist1 - dist2); %bigger better
                             value(j) = slope;
                         end
                     end
                 end
             end
         end 
       end
         q2 = q1 - 1;
         if q1>50&&q1<205
             q_low=q1-50;
             for j=q_low:q2
                 dist1 = mse_whole(m,n,q1);
                 dist2 = mse_whole(m,n,j);
                 rate1 = rate_whole(m,n,q1);
                 rate2 = rate_whole(m,n,j);
                 if rate2~=rate1
                     slope = (dist1 - dist2)/(rate2 - rate1); %bigger better
                     value(j) = slope;
                 end
             end
         else
             if q1<=50
                 for j=1:q2
                     dist1 = mse_whole(m,n,q1);
                     dist2 = mse_whole(m,n,j);
                     rate1 = rate_whole(m,n,q1);
                     rate2 = rate_whole(m,n,j);
                     if rate2~=rate1
                         slope = (dist1 - dist2)/(rate2 - rate1); %bigger better
                         value(j) = slope;
                     end
                 end
             else
                 if q1>=205
                     q_low=q1-50;
                     for j=q_low:q2
                         dist1 = mse_whole(m,n,q1);
                         dist2 = mse_whole(m,n,j);
                         rate1 = rate_whole(m,n,q1);
                         rate2 = rate_whole(m,n,j);
                         if rate2~=rate1
                             slope = (dist1 - dist2)/(rate2 - rate1); %bigger better
                             value(j) = slope;
                         end
                     end
                 end
             end
         end
    [value_new, index2]=sort(value,'descend');
    minus_value(1,i)=value_new(1,1);
    minus_index(1,i) = index2(1,1); 
end
[~, index1]=sort(minus_value,'descend');
index_new=index1(1:k);
end


function out = quantLumMat(lumMat, quality)

if quality <= 50
    quality = 5000 / quality;
else
    quality = 200 - quality * 2;
end
matr = lumMat;
for i=1:64
    matr(i) = floor((matr(i) * quality + 50) / 100);
    if matr(i) <= 0
        matr(i) = 1;
    elseif matr(i) > 255
        matr(i) = 255;
    end
end
out = matr;
end